port = Integer(ENV.fetch("PORT", 3000))
listen "#{ENV.fetch('PITCHFORK_HOST', '127.0.0.1')}:#{port}"
worker_processes Integer(ENV.fetch("WEB_CONCURRENCY", 2))
timeout Integer(ENV.fetch("PITCHFORK_TIMEOUT", 30))
