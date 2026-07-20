CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Bootstrap", "mise run bootstrap-check"
  step "Lint", "mise run lint"
  step "Typecheck", "mise run typecheck"
  step "Security", "mise run security"
  step "Tests", "mise run test"
  step "Build", "mise run build"
end
