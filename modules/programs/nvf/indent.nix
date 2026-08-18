{
  # Every tab and space setting for Neovim, in one place. Nothing about
  # indentation belongs in nvf.nix.
  #
  # The precedence ladder, highest first: a file's modeline, the project's
  # `.editorconfig`, vim-sleuth's detection of the surrounding code, the
  # per-filetype defaults below, Neovim's runtime ftplugins, then the baseline.
  # `.editorconfig` is the keystone: Neovim, sleuth, stylua, shfmt and prettier
  # all read it, so one project file configures editor and formatters alike.
  #
  # Design and the measurements behind every value: specs/neovim-indentation.md.
  flake.modules.homeManager.nvf = {lib, ...}: let
    # Filetypes whose indentation treesitter measurably gets wrong. Consumed
    # twice below — by nvf's exclusion option and by the repair block — so the
    # two can never disagree.
    treesitterExcludes = ["yaml" "c" "cpp"];
  in {
    programs.nvf.settings.vim = {
      # ----------------------------------------------------------------
      # Baseline — filetypes with no ftplugin and no default below
      # ----------------------------------------------------------------
      options = {
        autoindent = true;
        expandtab = true;
        # Zero means "follow tabstop", so one value sets both the width a tab
        # renders as and the size of one indent step.
        shiftwidth = 0;
        tabstop = 4;
      };

      # ----------------------------------------------------------------
      # Detection — .editorconfig, then the file, then its neighbours
      # ----------------------------------------------------------------
      utility.sleuth.enable = true;

      # Per-filetype policy, handed to sleuth as its `defaults`, which it
      # merges *under* both `.editorconfig` and its own detection while still
      # overriding Neovim's ftplugins — exactly the rung this policy occupies.
      # Sleuth infers the rest: `tabstop=N` implies tabs, `shiftwidth=N` implies
      # spaces.
      #
      # An entry earns its place only by disagreeing with the layers below it,
      # so a value that merely restates an ftplugin must be deleted. python,
      # rust, java and lua are absent for that reason.
      globals = {
        # alejandra emits 2 and accepts no options at all.
        sleuth_nix_defaults = "shiftwidth=2";

        # prettier's default is 2, and it owns all of these filetypes.
        sleuth_css_defaults = "shiftwidth=2";
        sleuth_html_defaults = "shiftwidth=2";
        sleuth_javascript_defaults = "shiftwidth=2";
        sleuth_json_defaults = "shiftwidth=2";
        sleuth_jsonc_defaults = "shiftwidth=2";
        sleuth_svelte_defaults = "shiftwidth=2";
        sleuth_typescript_defaults = "shiftwidth=2";

        # taplo's default is 2.
        sleuth_toml_defaults = "shiftwidth=2";

        # deno fmt emits 2, while markdown's ftplugin asks for 4.
        sleuth_markdown_defaults = "shiftwidth=2";

        # clang-format emits 2; the engine override lives below.
        sleuth_c_defaults = "shiftwidth=2";
        sleuth_cpp_defaults = "shiftwidth=2";

        # gofmt uses tabs, conventionally rendered 8 wide; go's ftplugin sets
        # only noexpandtab and leaves the width at the baseline.
        sleuth_go_defaults = "tabstop=8";

        # Chosen convention rather than shfmt's default, which is tabs — so a
        # repository declaring nothing will still be tabbed on save. See the
        # spec's Consequences.
        sleuth_bash_defaults = "shiftwidth=2";
        sleuth_sh_defaults = "shiftwidth=2";
      };

      # ----------------------------------------------------------------
      # Engine — which mechanism decides where a new line starts
      # ----------------------------------------------------------------
      # Treesitter by default, because it measurably beats Neovim's indent
      # scripts (python 0 changed lines against 60, go 2 against 1121). These
      # two lose to it, so they opt out and nvf leaves 'indentexpr' alone:
      # yaml, because treesitter double-indents flush sequence items and then
      # cascades over whitespace-significant text; c and cpp, because 'cindent'
      # changed 55 lines where treesitter changed 272.
      treesitter.indent.excludes = treesitterExcludes;

      # Excluding c and cpp only clears 'indentexpr' — Neovim ships no C indent
      # script behind it, so without this they would fall to plain 'autoindent'.
      luaConfigRC.cindent = ''
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("indent_cindent", {clear = true}),
          pattern = {"c", "cpp"},
          callback = function(args)
            vim.bo[args.buf].cindent = true
          end,
        })
      '';

      # Repair for an upstream defect, not policy of our own.
      #
      # lz.n registers its lazy-loading autocommands with `once = true`, and an
      # autocommand that deletes itself mid-dispatch truncates the chain it was
      # dispatched from (neovim/neovim#25526, which lz.n's own source flags as a
      # workaround). Filetype detection dispatches FileType *nested* inside
      # BufReadPost, so for the filetypes lz.n lazy-loads on — lua and markdown
      # here — that deletion truncates the enclosing BufReadPost chain and
      # sleuth's initial run never happens. Its own FileType hook cannot recover,
      # because that hook only re-applies when `b:sleuth` already exists.
      #
      # So re-apply both starved layers once per buffer. Re-dispatching FileType
      # instead would re-run the ftplugins and clobber the widths sleuth just
      # chose.
      luaConfigRC.indentRepair = ''
        local excluded = ${
          "{" + lib.concatMapStringsSep ", " (ft: "${ft} = true") treesitterExcludes + "}"
        }

        vim.api.nvim_create_autocmd("BufEnter", {
          group = vim.api.nvim_create_augroup("indent_repair", {clear = true}),
          callback = function(args)
            local buf = args.buf
            if vim.b[buf].indent_repaired or vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "" then
              return
            end
            vim.b[buf].indent_repaired = true

            if not excluded[vim.bo[buf].filetype] then
              vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end

            if vim.b[buf].sleuth == nil then
              pcall(vim.cmd, "silent! Sleuth")
            end
          end,
        })
      '';

      # ----------------------------------------------------------------
      # Formatter deference
      # ----------------------------------------------------------------
      # nvf derives width flags from the buffer for these four, and a
      # command-line flag outranks a project's own config file — verified: a
      # `.stylua.toml` asking for 8 formatted to 2. Restoring each formatter's
      # own arguments lets it read `.stylua.toml`, `.taplo.toml`, `deno.json`
      # or `.editorconfig` instead.
      formatter.conform-nvim.setupOpts.formatters = let
        ownArgs = name:
          lib.mkForce (lib.generators.mkLuaInline
            "require('conform.formatters.${name}').args");
      in {
        astyle.args = ownArgs "astyle";
        deno.args = ownArgs "deno_fmt";
        stylua.args = ownArgs "stylua";
        taplo.args = ownArgs "taplo";
      };
    };
  };
}
