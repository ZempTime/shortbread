# frozen_string_literal: true

require "open3"

# The review surface a Viewer uses to select text and leave a Comment.
#
# Site hosts serve Release bytes verbatim and deliberately serve no Vite or static assets, so the
# surface arrives as one self-contained script injected into HTML responses at serve time. The
# stored Blob is never rewritten: the Release stays content-addressed to the uploaded bytes and
# the ETag remains the Blob digest. Injection is a property of the response, not of the content.
class ReviewSurface
  # Under the reserved prefix publishing already refuses, so a Release can never shadow it.
  SCRIPT_PATH = "/_shortbread/review.js"

  SOURCES = %w[
    app/frontend/anchoring/anchoring.ts
    app/frontend/anchoring/extraction.ts
    app/frontend/anchoring/capture.ts
    app/frontend/anchoring/review.ts
  ].freeze

  BODY_CLOSE = %r{</body>}i

  class << self
    def inject(html)
      tag = %(<script type="module" src="#{SCRIPT_PATH}"></script>)
      return html.sub(BODY_CLOSE) { "#{tag}#{Regexp.last_match(0)}" } if html.match?(BODY_CLOSE)

      "#{html}#{tag}"
    end

    def script
      Rails.env.local? ? build_script : cached_script
    end

    private

    def cached_script
      @cached_script ||= build_script
    end

    # Node 24 strips TypeScript types natively, so the browser runs the real source with no
    # bundler dependency added to the baseline.
    def build_script
      output, status = Open3.capture2("node", "--eval", strip_program, chdir: Rails.root.to_s)
      raise "review surface build failed" unless status.success?

      output
    end

    def strip_program
      <<~JS
        const { stripTypeScriptTypes } = require('node:module');
        const { readFileSync } = require('node:fs');
        const aliases = [];
        const stripped = #{SOURCES.to_json}.map((path) => {
          const source = stripTypeScriptTypes(readFileSync(path, 'utf8'), { mode: 'strip' });
          for (const line of source.match(/^import[^\\n]*\\n/gm) ?? []) {
            for (const [, original, alias] of line.matchAll(/(\\w+)\\s+as\\s+(\\w+)/g)) {
              if (original !== 'type') aliases.push(`const ${alias} = ${original};`);
            }
          }
          return source.replace(/^import[^\\n]*\\n/gm, '').replace(/^export /gm, '');
        });
        process.stdout.write(stripped.join('\\n') + '\\n' + aliases.join('\\n'));
      JS
    end
  end
end
