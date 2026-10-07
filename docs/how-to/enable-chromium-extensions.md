# Enable Nix-installed Chromium extensions

Use this procedure after a home rebuild adds an extension to
ungoogled-chromium. On macOS the browser installs each new extension disabled.
On Linux it installs the extension enabled, so step 6 does not apply.

1. Rebuild your home, as in [Rebuild your home](rebuild-your-home.md):

   ```sh
   hr
   ```

2. Quit ungoogled-chromium completely. On macOS, use Cmd+Q, because closing
   the window leaves the browser running.

3. Open ungoogled-chromium.

4. Confirm that the extension files exist. On macOS, run this command:

   ```sh
   ls ~/Library/Application\ Support/Chromium/External\ Extensions/
   ```

   On Linux, run this command:

   ```sh
   ls ~/.config/chromium/External\ Extensions/
   ```

   The output lists one `<id>.json` file for each extension. uBlock Origin's
   file is `blockjmkbacgjkknlgpkjjiijinjdanf.json`. A home with Claude Code
   also has `ghpielhenbpoohlpehajamjhhoajejph.json`, for Open Claude in Chrome.

5. Open `chrome://extensions`.

6. On macOS, turn on the toggle of each new extension.

The extensions page shows each extension as enabled. The extension stays
enabled across browser restarts.

## Restore a removed extension

The browser does not reinstall an extension that you removed in the browser.
A rebuild does not restore it either.

1. Open `chrome://extensions`.
2. Enable the removed extension again.

See [Chromium extensions](../explanation/chromium-extensions.md) for why the
browser behaves this way.
