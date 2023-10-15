let
  jasper = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA1mAN5Db7eZ0iuBGGxdPqQCR2l6jDZBjgX4ZVOcip27";
  lemmy-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIniUrQZX0vYZKXqWTE2OvVVIjC/QO85TEG+PQPfmGSb";
in {
  # contains cachix agent token: CACHIX_AGENT_TOKEN=<token>
  "cachix-agent.age".publicKeys = [jasper lemmy-host];
}
