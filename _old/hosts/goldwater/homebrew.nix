_: {
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
    };
    casks = [
      "github" # GitHub Desktop
      "ungoogled-chromium"
    ];
  };
}
