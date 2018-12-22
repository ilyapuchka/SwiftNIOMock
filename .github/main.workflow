workflow "Test" {
  on = "push"
  resolves = ["build"]
}

action "build" {
  uses = "docker://swift:4.2"
  runs = "swift build --package-path SwiftNIOMock"
  secrets = ["GITHUB_TOKEN"]
}
