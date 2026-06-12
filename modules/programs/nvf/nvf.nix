{inputs, ...}: {
  # Declarative Neovim via nvf, configured through home-manager so the *same*
  # editor is shared by every user on every host (Linux and macOS).
  # https://github.com/notashelf/nvf
  #
  # Moved here verbatim from the old system-level programs.nvf; the option
  # namespace is identical between the NixOS and home-manager nvf modules.

  flake-file.inputs.nvf.url = "github:notashelf/nvf";

  flake.modules.homeManager.nvf = {
    pkgs,
    lib,
    ...
  }: {
    imports = [inputs.nvf.homeManagerModules.default];

    programs.nvf = {
      enable = true;
      defaultEditor = true;

      settings.vim = {
        viAlias = true;
        vimAlias = true;

        # Turn off the annoying notification sound on invalid actions
        bell = "none";

        # Set the clipboard so the unnamed register is the system clipboard
        clipboard = {
          enable = true;
          registers = "unnamedplus";
        };

        # Diagnostics for plugins to communicate error states
        diagnostics = {
          enable = true;
          config = {
            signs = true;
            underline = true;
            update_in_insert = false;
            virtual_lines = true;
          };
        };

        # Cache lua bytecode for faster launches
        enableLuaLoader = true;

        # Set leader key for shortcuts (space is common)
        globals.mapleader = " ";

        # Set leader key for buffer-local mappings
        globals.maplocalleader = "\\";

        # Pressing escape clears all highlighted search results
        hideSearchHighlight = true;

        # How to display the line number for the current line
        lineNumberMode = "relNumber";

        # Store intermediate files in XDG compliant location to keep work dir clean
        preventJunkFiles = true;

        # How to do a search, smart means case insensitive unless there is any upper case
        searchCase = "smart";

        # Fallback syntax highlighting when treesitter is not avaliable
        syntaxHighlighting = true;

        # Persist undo state across opening and closing neovim
        undoFile.enable = true;

        # ----------------
        # Colorscheme
        # ----------------
        # On NixOS, stylix themes nvf automatically (gruvbox-material-dark-hard).
        # The macs have no stylix, so to get an identical look there, enable the
        # self-contained base16 theme below. Left disabled until the exact nvf
        # theme option + palette are confirmed on a machine that can build
        # (verify hexes against
        # ${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml).
        #
        # theme = {
        #   enable = true;
        #   name = "base16";
        #   base16-colors = {
        #     base00 = "#1d2021"; base01 = "#3c3836";
        #     base02 = "#504945"; base03 = "#665c54";
        #     base04 = "#bdae93"; base05 = "#d4be98";
        #     base06 = "#ebdbb2"; base07 = "#fbf1c7";
        #     base08 = "#ea6962"; base09 = "#e78a4e";
        #     base0A = "#d8a657"; base0B = "#a9b665";
        #     base0C = "#89b482"; base0D = "#7daea3";
        #     base0E = "#d3869b"; base0F = "#bd6f3e";
        #   };
        # };

        # ----------------
        # Global Options
        # ----------------
        options = {
          autoindent = true; # Automatically indent on a newline
          cmdheight = 1; # The height of the command pane in lines
          cursorlineopt = "both"; # The way to highlight the line the cursor is on
          foldlevel = 99; # stops auto folding when opening document
          mouse = "nvi"; # Supported modes for mouse control
          shiftwidth = 0; # Number of spaces to use for autoindent, 0 means use tabstop vaule
          signcolumn = "yes"; # Show the sign column (what is sign column)
          splitbelow = true; # On true new splits open below instead of above
          splitright = true; # New splits will open to the right
          tabstop = 2; # The number of spaces a tab counts for
          termguicolors = true; # On true use 256 colors for terminal
          tm = 500; # The time in ms that Neovim will wait for the next key in chord
          updatetime = 25; # The number of ms until the cursor hold event is triggered
          wrap = false; # Whether to wrap lines if they go off screen
        };

        # ---------------------------------------
        # Lazy Loading and non-included plugins
        # ---------------------------------------
        lazy = {
          enable = true; # Enable lazy loading for plugins to load in only when needed
          enableLznAutoRequire = true; # Builtin plugins need this, only turn off for debug
          plugins = {
            # Claude Code IDE integration: spawns the `claude` CLI
            "claudecode.nvim" = {
              package = pkgs.vimPlugins.claudecode-nvim;
              setupModule = "claudecode";
              setupOpts = {};
              cmd = [
                "ClaudeCode"
                "ClaudeCodeFocus"
                "ClaudeCodeSelectModel"
                "ClaudeCodeAdd"
                "ClaudeCodeSend"
                "ClaudeCodeTreeAdd"
                "ClaudeCodeStatus"
                "ClaudeCodeStart"
                "ClaudeCodeStop"
                "ClaudeCodeOpen"
                "ClaudeCodeClose"
                "ClaudeCodeDiffAccept"
                "ClaudeCodeDiffDeny"
                "ClaudeCodeCloseAllDiffs"
              ];

              keys = [
                {
                  key = "<leader>at";
                  mode = "n";
                  action = "<cmd>ClaudeCode<cr>";
                  desc = "Toggle Claude";
                }
                {
                  key = "<leader>af";
                  mode = "n";
                  action = "<cmd>ClaudeCodeFocus<cr>";
                  desc = "Focus Claude";
                }
                {
                  key = "<leader>ar";
                  mode = "n";
                  action = "<cmd>ClaudeCode --resume<cr>";
                  desc = "Resume Claude";
                }
                {
                  key = "<leader>ac";
                  mode = "n";
                  action = "<cmd>ClaudeCode --continue<cr>";
                  desc = "Continue Claude";
                }
                {
                  key = "<leader>am";
                  mode = "n";
                  action = "<cmd>ClaudeCodeSelectModel<cr>";
                  desc = "Select Claude model";
                }
                {
                  key = "<leader>ab";
                  mode = "n";
                  action = "<cmd>ClaudeCodeAdd %<cr>";
                  desc = "Add current buffer";
                }
                {
                  key = "<leader>as";
                  mode = "v";
                  action = "<cmd>ClaudeCodeSend<cr>";
                  desc = "Send to Claude";
                }
                {
                  # In file explorers, <leader>as adds the file under the
                  # cursor instead of sending a selection.
                  key = "<leader>as";
                  mode = "n";
                  action = "<cmd>ClaudeCodeTreeAdd<cr>";
                  desc = "Add file";
                  ft = ["NvimTree" "neo-tree" "oil" "minifiles" "netrw" "snacks_picker_list"];
                }
                {
                  key = "<leader>aa";
                  mode = "n";
                  action = "<cmd>ClaudeCodeDiffAccept<cr>";
                  desc = "Accept diff";
                }
                {
                  key = "<leader>ad";
                  mode = "n";
                  action = "<cmd>ClaudeCodeDiffDeny<cr>";
                  desc = "Deny diff";
                }
              ];
            };
          };
        };

        # ------------------
        # Language Support
        # ------------------
        languages = {
          enableFormat = true;
          enableTreesitter = true;
          enableExtraDiagnostics = true;

          bash.enable = true;

          clang.enable = true;

          css.enable = true;

          dart = {
            enable = true;
            dap.enable = true;
            flutter-tools.enable = true;
          };

          go.enable = true;

          html.enable = true;

          java.enable = true;

          json.enable = true;

          lua = {
            enable = true;
            lsp.lazydev.enable = true; # Extra config for NeoVim Files
          };

          markdown = {
            enable = true;
            extensions.render-markdown-nvim.enable = true; # Inline markdown rendering
          };

          nix = {
            enable = true;
            format.type = ["alejandra"];
            lsp.servers = ["nil"];
          };

          python = {
            enable = true;
            lsp.servers = ["pyright"];
            format.type = ["black"];
          };

          rust = {
            enable = true;
            extensions.crates-nvim.enable = true;
          };

          svelte.enable = true;

          toml.enable = true;

          # Both JavaScript and TypeScript
          typescript = {
            enable = true;
            format.type = ["prettier"];
          };

          yaml.enable = true;
        };

        # nvf always passes `lsp.color` to flutter-tools' setup, which trips a
        # deprecation warning on Neovim 0.12+ even with color support disabled.
        # Re-emit the same setup call without that key until nvf drops it
        # upstream.
        pluginRC.flutter-tools = lib.mkForce (inputs.nvf.lib.nvim.dag.entryAfter ["lsp-servers"] ''
          require('flutter-tools').setup {
            flutter_path = "${pkgs.flutter}/bin/flutter",
            lsp = {
              capabilities = capabilities,
            },
            debugger = {
              enabled = true,
            },
          }
        '');

        # ---------
        # Lualine
        # ---------
        statusline.lualine = {
          enable = true;
          setupOpts.sections.lualine_c = [
            (lib.generators.mkLuaInline ''
              function()
                if vim.bo.filetype == "oil" then
                  local ok, oil = pcall(require, "oil")
                  if ok then
                    local dir = oil.get_current_dir()
                    if dir then
                      return vim.fn.fnamemodify(dir, ":~")
                    end
                  end
                end
                return "%f"
              end
            '')
          ];

          setupOpts.sections.lualine_b = [
            (lib.generators.mkLuaInline ''
              function()
                if vim.bo.filetype == "oil" then
                  return ""
                end
                local name = vim.fn.expand("%:~:.")
                return vim.fs.basename(name)
              end
            '')
          ];
        };

        # ---------------------
        # Global LSP Behavior
        # ---------------------
        lsp = {
          enable = true;
          formatOnSave = true;

          # Pretty icons next to completion items
          lspkind.enable = true;

          # Enhanced LSP UI
          lspsaga = {
            enable = true;
            # mappings = {
            #   codeAction = "<leader>ca";
            #   definiton = "gd";
            #   hover = "K";
            #   rename = "<leader>rn";
            # };
          };

          # Inline Errors
          trouble.enable = true;

          # Function signature help popup
          nvim-docs-view.enable = true;
        };

        # ------------
        # Treesitter
        # ------------
        treesitter = {
          enable = true; # Use a full syntax tree for parser
          fold = true; # Use treesitter for folding text (collapse)
          addDefaultGrammars = true; # A set of starter grammars
          autotagHtml = true; # Automatically add matching closing tags to HTML

          # Function and class headers at the top
          context = {
            enable = true;
            setupOpts.max_lines = 4;
          };

          textobjects = {
            enable = true;
            setupOpts = {
              # Move between functions and classes
              move = {
                enable = true;
                gotoNextStart = {
                  "]m" = "@function.outer";
                  "]]" = "@class.outer";
                };
                gotoPreviousStart = {
                  "[m" = "@function.outer";
                  "[[" = "@class.outer";
                };
              };

              # Select blocks of code semantically
              select = {
                enable = true;
                lookahead = true;
                keymaps = {
                  "af" = "@function.outer";
                  "if" = "@function.inner";
                  "ac" = "@class.outer";
                  "ic" = "@class.inner";
                  "aa" = "@parameter.outer";
                  "ia" = "@parameter.inner";
                };
              };
            };
          };
        };

        # ------------
        # Completion
        # ------------
        autocomplete.nvim-cmp = {
          enable = true;

          mappings = {
            confirm = "<CR>";
            next = "<Tab>";
            previous = "<S-Tab>";
            scrollDocsUp = "<C-b>";
            scrollDocsDown = "<C-f>";
            complete = "<C-Space>";
          };
        };

        # ---------------------------------
        # Snippets for custom completions
        # ---------------------------------
        snippets.luasnip = {
          enable = true;
          providers = ["friendly-snippets"];
        };

        # -----------
        # Telescope
        # -----------
        telescope = {
          enable = true;
          mappings = {
            findFiles = "<leader>ff";
            liveGrep = "<leader>fg";
            buffers = "<leader>fb";
            helpTags = "<leader>fh";
            diagnostics = "<leader>fd";
            lspReferences = "<leader>fr";
            lspDefinitions = "<leader>fD";
            gitCommits = "<leader>gc";
            gitBranches = "<leader>gb";
          };
        };

        # ----------------------------
        # Snacks (QoL plugin bundle)
        # ----------------------------
        # claudecode.nvim's recommended terminal provider.
        utility.snacks-nvim.enable = true;

        # ---------------
        # File Explorer
        # ---------------
        utility.oil-nvim = {
          enable = true;
          gitStatus.enable = true;
          setupOpts = {
            keymaps = {
              "<C-h>" = false;
              "<C-l>" = false;
              "<C-r>" = "actions.refresh";
              "<C-w><CR>" = "actions.select_vsplit";
              "<C-w><C-CR>" = "actions.select_split";
            };
          };
        };

        # -----------
        # Dashboard
        # -----------
        dashboard.alpha = {
          enable = true;
        };

        # ----------------------------
        # Keybind hints (which-key)
        # ----------------------------
        # Press a prefix (e.g. <leader>) and pause to get a popup of every
        # mapping that continues from there. Purely informational; never
        # blocks or changes what the keys do.
        binds.whichKey = {
          enable = true;
          setupOpts = {
            preset = "modern"; # Full-width rounded panel at the bottom
            delay = 200; # ms of hesitation before the popup appears

            # Name the key groups so prefixes show a label instead of "+prefix"
            spec = [
              (lib.generators.mkLuaInline ''{ "<leader>a", group = "AI/Claude Code" }'')
              (lib.generators.mkLuaInline ''{ "<leader>f", group = "Find/Telescope" }'')
              (lib.generators.mkLuaInline ''{ "<leader>g", group = "Git" }'')
            ];
          };
        };

        # ---------------
        # Other keymaps
        # ---------------
        keymaps = [
          {
            key = "<C-h>";
            mode = "n";
            action = "<C-w>h";
            desc = "Move right one window";
          }
          {
            key = "<C-j>";
            mode = "n";
            action = "<C-w>j";
            desc = "Move down one window";
          }
          {
            key = "<C-k>";
            mode = "n";
            action = "<C-w>k";
            desc = "Move up one window";
          }
          {
            key = "<C-l>";
            mode = "n";
            action = "<C-w>l";
            desc = "Move left one window";
          }
          {
            key = "-";
            mode = "n";
            action = "<cmd>Oil<cr>";
            desc = "Open oil (parent directory)";
          }
          {
            # Recommended by the which-key README: show only the keymaps
            # local to the current buffer (e.g. oil's browser mappings).
            key = "<leader>?";
            mode = "n";
            lua = true;
            action = ''function() require("which-key").show({ global = false }) end'';
            desc = "Buffer local keymaps (which-key)";
          }
          {
            key = "<A-v>";
            mode = ["n" "x"];
            action = "<C-v>";
            desc = "Visual block mode (ctrl+v is paste in ghostty)";
          }
        ];
      };
    };
  };
}
