workflow "Test" {
  on = "push"
  resolves = ["test"]
}

action "test" {
  uses = "ilyapuchka/SwiftGitHubAction@master"
  args = "test --package-path SwiftNIOMock"
}
