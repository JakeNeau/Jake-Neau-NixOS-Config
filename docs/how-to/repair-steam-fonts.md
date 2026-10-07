# Repair Steam font rendering

Use this procedure after changing the declared Steam font set when the client
still shows missing or invisible text.

1. Exit Steam completely:

   ```sh
   steam -shutdown
   ```

2. Confirm that Steam has stopped:

   ```sh
   pgrep -a steam
   pgrep -a steamwebhelper
   ```

   Both commands should produce no output.

3. Remove the regenerable user Fontconfig cache:

   ```sh
   rm -rf ~/.cache/fontconfig
   ```

4. Start Steam normally. Fontconfig recreates the cache from the bounded font
   set.

5. Confirm that the expected Arial-compatible fallback is available:

   ```sh
   steam-run fc-match Arial
   ```

The result should name Liberation Sans or another declared compatible fallback.
See [Steam font compatibility](../explanation/steam-font-compatibility.md) for
the configuration rationale.
