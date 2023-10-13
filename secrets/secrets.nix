let
  jasper = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA1mAN5Db7eZ0iuBGGxdPqQCR2l6jDZBjgX4ZVOcip27";
  lemmy-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIniUrQZX0vYZKXqWTE2OvVVIjC/QO85TEG+PQPfmGSb root@lemmy-deploy";
in {
  # contains cachix agent token: CACHIX_AGENT_TOKEN=<token>
  "cachix-agent.age".publicKeys = [jasper lemmy-host];

  # define who can decrypt the secret:
  #"some-secret.age".publicKeys = [jasper];

  # create the secret:
  #agenix -e some-secret.age

  # add secret to a NixOS module config:
  #age.secrets.some-secret.file = ../secrets/some-secret.age;

  # reference the mount path of the secret somewhere:
  #config.age.secrets.some-secret.path
}
