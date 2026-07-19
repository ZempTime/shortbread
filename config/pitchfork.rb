listen ENV.fetch("PORT", 3000)
worker_processes Integer(ENV.fetch("WEB_CONCURRENCY", 2))
timeout Integer(ENV.fetch("PITCHFORK_TIMEOUT", 30))

preload_app true
