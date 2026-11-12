# Who can decrypt which secret; read by the `agenix` CLI, not by the flake. Edit or create one
# with `nix run --inputs-from . agenix -- -e <name>.age` in this directory, and after changing
# recipients re-encrypt everything with `-r`.
let
  # Edits secrets; ~/.ssh/id_ed25519 on goldwater.
  jonas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4p5xyCPbCfuOf+bCNXTi0pcDNXsAdcABSEcgx/WujU";
  # /etc/ssh/ssh_host_ed25519_key.pub on the host.
  ardmore = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUKx/lzVEe1tJbz4Dcx58PoNMGvQ8O3zjKiJjasDJbs";
in
{
  # `access-tokens = github.com=<PAT>`: read access to the private refractory repository.
  "github-token.conf.age".publicKeys = [
    jonas
    ardmore
  ];
  # TELEGRAM_BOT_TOKEN=… and TELEGRAM_CHAT_ID=…, for Alertmanager.
  "telegram.env.age".publicKeys = [
    jonas
    ardmore
  ];
  # linear oauth and webhook secrets for the metafactory experiment
  "metafactory-webhook-secret.age".publicKeys = [
    jonas
    ardmore
  ];
  "metafactory-linear-client-secret.age".publicKeys = [
    jonas
    ardmore
  ];
  # CLAUDE_CODE_OAUTH_TOKEN=<token>, from `claude setup-token`: the metafactory's agents' Claude Code.
  "metafactory-claude-token.env.age".publicKeys = [
    jonas
    ardmore
  ];
}
