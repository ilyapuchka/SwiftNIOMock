workflow "Test" {
  on = "push"
  resolves = ["build"]
}

action "build" {
  uses = "docker://swift:4.2"
  runs = "swift test --package-path SwiftNIOMock -Xswiftc '-target' -Xswiftc 'x86_64-apple-macosx10.13'"
  secrets = ["GITHUB_TOKEN"]
}
