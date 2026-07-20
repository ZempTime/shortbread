# frozen_string_literal: true

require "json"
require "open3"
require "pathname"

module SecretScan
  FNOX_ARGUMENTS = [
    "--config", "fnox.toml", "--non-interactive", "scan", "--format", "json",
    "--ignore", ".git/**", "--ignore", "tmp/**", "--ignore", "node_modules/**",
    "--ignore", "anycable.toml", "."
  ].freeze
  FINDING_KEYS = %w[column detector line path redacted severity].freeze
  SUMMARY_KEYS = %w[files_scanned files_with_findings findings].freeze
  TEST_FILE = /(?:_test\.(?:rb|go)|\.(?:test|spec)\.[A-Za-z0-9]+)\z/
  CODE_EXTENSIONS = %w[.bash .c .cc .cpp .go .java .js .jsx .php .py .rb .rs .sh .ts .tsx].freeze
  FAILURE = "Secret scan failed.\n"
  SUCCESS = "Secret scan passed.\n"

  class InvalidScan < StandardError; end

  module_function

  def run(arguments, stdout: $stdout, stderr: $stderr)
    raise InvalidScan unless arguments.length == 1

    root = Pathname.new(arguments.fetch(0)).realpath
    raise InvalidScan unless root.directory?

    scanner_stdout, _scanner_stderr, status = Open3.capture3("fnox", *FNOX_ARGUMENTS, chdir: root.to_s)
    raise InvalidScan unless [ 0, 1 ].include?(status.exitstatus)

    payload = JSON.parse(scanner_stdout)
    findings = validate_payload(payload, status: status)
    findings.each { |finding| validate_finding(root, finding) }
    stdout.write(SUCCESS)
    0
  rescue InvalidScan, JSON::ParserError, Errno::ENOENT, SystemCallError, ArgumentError, EncodingError
    stderr.write(FAILURE)
    1
  end

  def validate_payload(payload, status:)
    raise InvalidScan unless payload.is_a?(Hash) && payload.keys.sort == %w[findings summary]

    findings = payload.fetch("findings")
    summary = payload.fetch("summary")
    raise InvalidScan unless findings.is_a?(Array)
    raise InvalidScan unless summary.is_a?(Hash) && summary.keys.sort == SUMMARY_KEYS
    raise InvalidScan unless positive_integer?(summary.fetch("files_scanned"))
    raise InvalidScan unless %w[files_with_findings findings].all? { |key| nonnegative_integer?(summary.fetch(key)) }
    raise InvalidScan unless summary.fetch("findings") == findings.length

    paths = findings.each_with_object([]) do |finding, values|
      values << finding["path"] if finding.is_a?(Hash)
    end
    raise InvalidScan unless summary.fetch("files_with_findings") == paths.uniq.length
    raise InvalidScan unless summary.fetch("files_scanned") >= summary.fetch("files_with_findings")
    expected_status = findings.empty? ? 0 : 1
    raise InvalidScan unless status.exitstatus == expected_status

    findings
  end

  def validate_finding(root, finding)
    raise InvalidScan unless finding.is_a?(Hash) && finding.keys.sort == FINDING_KEYS
    raise InvalidScan unless finding.fetch("detector") == "secret-assignment"
    raise InvalidScan unless finding.fetch("severity").is_a?(String) && finding.fetch("redacted").is_a?(String)
    raise InvalidScan unless positive_integer?(finding.fetch("line")) && positive_integer?(finding.fetch("column"))

    relative_path = validate_relative_path(finding.fetch("path"))
    source_path = source_path(root, relative_path)
    source = source_path.binread.force_encoding(Encoding::UTF_8)
    raise InvalidScan unless source.valid_encoding?

    line = source.lines.fetch(finding.fetch("line") - 1)
    column = finding.fetch("column")
    raise InvalidScan if column > line.bytesize
    return if test_path?(relative_path) && explicit_synthetic_literal_at?(line, column)

    rhs = assignment_rhs(line, column)
    return if test_path?(relative_path) && explicit_synthetic_literals?(rhs)

    raise InvalidScan unless acceptable_rhs?(rhs, relative_path)
  rescue IndexError
    raise InvalidScan
  end

  def validate_relative_path(raw_path)
    raise InvalidScan unless raw_path.is_a?(String) && !raw_path.empty? && raw_path.valid_encoding?
    raise InvalidScan if raw_path.include?("\\") || raw_path.match?(/[[:cntrl:]]/)

    path = Pathname.new(raw_path)
    raise InvalidScan if path.absolute? || path.cleanpath.to_s != raw_path
    raise InvalidScan if path.each_filename.any? { |segment| segment == "." || segment == ".." }

    path
  end

  def source_path(root, relative_path)
    cursor = root
    relative_path.each_filename do |segment|
      cursor = cursor.join(segment)
      raise InvalidScan if cursor.symlink?
    end
    raise InvalidScan unless cursor.file?

    resolved = cursor.realpath
    prefix = "#{root}#{File::SEPARATOR}"
    raise InvalidScan unless resolved.to_s.start_with?(prefix)

    resolved
  end

  def assignment_rhs(line, column)
    source = line.byteslice(column - 1..)
    raise InvalidScan unless source&.valid_encoding?

    boundary = assignment_boundary(source)
    segment = source.byteslice(0, boundary).to_s.strip
    raise InvalidScan if segment.empty?

    segment
  end

  def assignment_boundary(source)
    stack = []
    quote = nil
    escaped = false
    source.each_char.with_index do |character, index|
      if quote
        if escaped
          escaped = false
        elsif character == "\\"
          escaped = true
        elsif character == quote
          quote = nil
        end
        next
      end

      if [ "\"", "'", "`" ].include?(character)
        quote = character
      elsif [ "(", "[", "{" ].include?(character)
        stack << { "(" => ")", "[" => "]", "{" => "}" }.fetch(character)
      elsif [ ")", "]", "}" ].include?(character)
        return index if stack.empty?
        raise InvalidScan unless stack.pop == character
      elsif character == "," && stack.empty?
        return index
      elsif character == ";" && stack.empty?
        return index
      end
    end
    raise InvalidScan if quote || escaped
    if stack.any?
      stripped = source.rstrip
      raise InvalidScan unless [ "(", "[", "{" ].include?(stripped[-1])
    end

    source.bytesize
  end

  def acceptable_rhs?(rhs, relative_path)
    literals = string_literals(rhs)
    return false if literals.any?
    return false if rhs.match?(/(?:%[qQx](?:\W)|<<[-~]?\w)/)
    return false unless CODE_EXTENSIONS.include?(relative_path.extname.downcase)
    return false if rhs.match?(/\A\s*(?:false|nil|null|true|[-+]?\d)/i)

    rhs.match?(/[A-Za-z_$@]/)
  end

  def explicit_synthetic_literal_at?(source, column)
    target = column - 1
    opening = nil
    quote = nil
    escaped = false

    source.bytes.each_with_index do |character, index|
      if quote
        if escaped
          escaped = false
        elsif character == "\\".ord
          escaped = true
        elsif character == quote
          if target.between?(opening, index)
            candidate = source.byteslice(opening..)
            boundary = assignment_boundary(candidate)
            return explicit_synthetic_literals?(candidate.byteslice(0, boundary).to_s)
          end
          opening = nil
          quote = nil
        end
      elsif [ "\"".ord, "'".ord, "`".ord ].include?(character)
        opening = index
        quote = character
      end
    end
    false
  end

  def explicit_synthetic_literals?(source)
    literals = string_literals(source)
    literals.any? && literals.all? { |literal| literal.match?(/synthetic|marker/i) }
  end

  def string_literals(source)
    literals = []
    quote = nil
    escaped = false
    content = +""
    source.each_char do |character|
      if quote
        if escaped
          content << character
          escaped = false
        elsif character == "\\"
          content << character
          escaped = true
        elsif character == quote
          literals << content
          quote = nil
          content = +""
        else
          content << character
        end
      elsif [ "\"", "'", "`" ].include?(character)
        quote = character
      end
    end
    raise InvalidScan if quote || escaped

    literals
  end

  def test_path?(path)
    first = path.each_filename.first
    %w[spec test tests].include?(first) || path.basename.to_s.match?(TEST_FILE)
  end

  def positive_integer?(value)
    value.is_a?(Integer) && value.positive?
  end

  def nonnegative_integer?(value)
    value.is_a?(Integer) && value >= 0
  end
end

exit SecretScan.run(ARGV) if $PROGRAM_NAME == __FILE__
