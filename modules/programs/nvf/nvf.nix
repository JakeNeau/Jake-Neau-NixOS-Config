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
    config,
    ...
  }: let
    # Local AI features (the <leader>ak hover and llama.vim autocomplete) only
    # exist on hosts that run the llama-server stack. The fact is forwarded from
    # the system level via systemConstants (see modules/system/types/local-ai).
    localAi = config.systemConstants.localAi;
  in {
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

        # vim-suda: transparently read/write root-owned files. smart_edit makes
        # an unwritable buffer save through sudo automatically (no :SudaWrite).
        # Read at plugin-load time, so it must be set here, before the plugin
        # sources (same early-globals path as mapleader above).
        globals.suda_smart_edit = 1;

        # llama.vim FIM autocomplete (local-ai hosts only). Point it at the
        # local FIM server's /infill port. llama.vim's defaults grab insert
        # <Tab>/<S-Tab> (clashing with nvim-cmp) and even normal-mode <Tab>/<Esc>
        # for its instruct feature, so move FIM-accept onto a free chord (<C-l>)
        # and disable everything we don't use ("" disables a keymap).
        globals.llama_config = lib.mkIf localAi {
          endpoint_fim = "http://127.0.0.1:8012/infill";
          keymap_fim_trigger = "<C-g>";
          keymap_fim_accept_full = "<C-l>";
          keymap_fim_accept_line = "";
          keymap_fim_accept_word = "";
          keymap_inst_trigger = "";
          keymap_inst_rerun = "";
          keymap_inst_continue = "";
          keymap_inst_accept = "";
          keymap_inst_cancel = "";
          keymap_debug_toggle = "";
          show_info = 0; # no inline inference-stats line after the suggestion
        };

        # llama.vim hardcodes its FIM ghost text to orange (highlight default
        # llama_hl_fim_hint guifg=#ff772f). Override it to the muted Comment
        # color so the suggestion reads as conventional gray ghost text;
        # linking to Comment tracks the theme on both NixOS (stylix) and Darwin.
        highlight.llama_hl_fim_hint = lib.mkIf localAi {link = "Comment";};

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
        # The macs have no stylix, so without a colorscheme treesitter has no
        # palette behind it and code looks washed out. Enable the same scheme
        # as a self-contained base16 theme — but only on Darwin, so it never
        # overrides stylix on NixOS. Palette copied verbatim from
        # ${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml.
        theme = lib.mkIf pkgs.stdenv.isDarwin {
          enable = true;
          name = "base16";
          base16-colors = {
            base00 = "#202020";
            base01 = "#2a2827";
            base02 = "#504945";
            base03 = "#5a524c";
            base04 = "#bdae93";
            base05 = "#ddc7a1";
            base06 = "#ebdbb2";
            base07 = "#fbf1c7";
            base08 = "#ea6962";
            base09 = "#e78a4e";
            base0A = "#d8a657";
            base0B = "#a9b665";
            base0C = "#89b482";
            base0D = "#7daea3";
            base0E = "#d3869b";
            base0F = "#bd6f3e";
          };
        };

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

            # llama.vim: inline FIM autocomplete from the local llama-server
            # (local-ai hosts only). Ghost text only matters while typing, so
            # load on first InsertEnter; configured via globals.llama_config.
            "llama.vim" = lib.mkIf localAi {
              package = pkgs.vimPlugins.llama-vim;
              event = ["InsertEnter"];
            };
          };
        };

        # ------------------------------
        # Eagerly-loaded extra plugins
        # ------------------------------
        # vim-suda is a vimscript plugin with no setup() call; its smart_edit
        # hook installs a BufEnter autocmd at load time, so it cannot be lazy
        # loaded (that would suppress the very event it relies on). Behaviour
        # is driven entirely by globals.suda_smart_edit above.
        extraPlugins = {
          vim-suda.package = pkgs.vimPlugins.vim-suda;
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

          # Code action on <leader>ca (nvf's default is <leader>la).
          mappings.codeAction = "<leader>ca";

          # Pretty icons next to completion items
          lspkind.enable = true;

          # Enhanced LSP UI
          lspsaga = {
            enable = true;
            # Kill the code-action lightbulb lspsaga otherwise draws on every
            # actionable line — both in the sign column and as end-of-line
            # virtual text.
            setupOpts.lightbulb.enable = false;
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

          # Don't preselect a candidate, and make <CR> confirm only one you
          # actually picked (Tab/S-Tab). nvf otherwise hardcodes a preselected
          # item + confirm({select = true}), so Enter swallows newlines into
          # whatever the menu happened to be showing.
          setupOpts = {
            completion.completeopt = "menu,menuone,noselect";
            mapping."<CR>" =
              lib.mkForce (lib.generators.mkLuaInline "cmp.mapping.confirm({ select = false })");
            # Explicit accept: <C-y> confirms the highlighted (or first) item,
            # for when you want to commit without reaching for Tab.
            mapping."<C-y>" =
              lib.generators.mkLuaInline "cmp.mapping.confirm({ select = true })";
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
            # Show dotfiles / hidden files in the browser by default.
            view_options.show_hidden = true;
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
        keymaps =
          [
            # Window navigation, normal mode. Terminal-mode variants below break
            # out of the terminal first (<C-\><C-n>) so the same chord escapes
            # the Claude Code terminal and lands in a code window in one press.
            {
              key = "<C-h>";
              mode = "n";
              action = "<C-w>h";
              desc = "Focus window left";
            }
            {
              key = "<C-j>";
              mode = "n";
              action = "<C-w>j";
              desc = "Focus window below";
            }
            {
              key = "<C-k>";
              mode = "n";
              action = "<C-w>k";
              desc = "Focus window above";
            }
            {
              key = "<C-l>";
              mode = "n";
              action = "<C-w>l";
              desc = "Focus window right";
            }
            {
              key = "<C-h>";
              mode = "t";
              action = "<C-\\><C-n><C-w>h";
              desc = "Focus window left";
            }
            {
              key = "<C-j>";
              mode = "t";
              action = "<C-\\><C-n><C-w>j";
              desc = "Focus window below";
            }
            {
              key = "<C-k>";
              mode = "t";
              action = "<C-\\><C-n><C-w>k";
              desc = "Focus window above";
            }
            {
              key = "<C-l>";
              mode = "t";
              action = "<C-\\><C-n><C-w>l";
              desc = "Focus window right";
            }
            {
              key = "-";
              mode = "n";
              action = "<cmd>Oil<cr>";
              desc = "Open oil (parent directory)";
            }
            # Cycle buffers (shadows the default screen-top/bottom motions).
            {
              key = "<S-l>";
              mode = "n";
              action = "<cmd>bnext<cr>";
              desc = "Next buffer";
            }
            {
              key = "<S-h>";
              mode = "n";
              action = "<cmd>bprevious<cr>";
              desc = "Previous buffer";
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
          ]
          # Local AI: AI "explain this" hover (see luaConfigRC below). Explains the
          # symbol under the cursor in normal mode, or the selection in visual
          # mode. Lives in the existing <leader>a "AI/Claude Code" which-key group.
          ++ lib.optionals localAi [
            {
              key = "<leader>ak";
              mode = ["n" "x"];
              lua = true;
              action = ''function() require("llama_explain").explain() end'';
              desc = "Explain symbol/selection (local AI)";
            }
          ];

        # <leader>ak hover: ask the local instruct server for a one-line
        # explanation, shown in the same float style as the LSP `K` hover. In
        # normal mode it explains the symbol under the cursor (with surrounding
        # lines as context); in visual mode it explains the highlighted region.
        # Async (vim.system) so it never blocks; exposed as the llama_explain
        # module the keymap above requires.
        luaConfigRC.llamaExplain = lib.mkIf localAi ''
          local M = {}
          function M.explain()
            local mode = vim.fn.mode()
            local visual = mode == "v" or mode == "V" or mode == "\22"
            local label, prompt
            if visual then
              local region = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
              -- Leave visual mode so the highlight doesn't linger behind the float.
              vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
              label = "selection"
              prompt = "Explain WHY this " .. vim.bo.filetype .. " code does what it does — its purpose and reasoning, not a line-by-line description of what it does:\n" .. table.concat(region, "\n")
            else
              local word = vim.fn.expand("<cword>")
              if word == "" then
                vim.notify("No symbol under cursor", vim.log.levels.WARN)
                return
              end
              local row = vim.fn.line(".")
              local ctx = table.concat(vim.fn.getline(math.max(1, row - 8), row + 8), "\n")
              label = word
              prompt = "Explain `" .. word .. "` in this " .. vim.bo.filetype .. " code:\n" .. ctx
            end
            local body = vim.json.encode({
              messages = {
                { role = "system", content = "You are a terse code explainer. Reply in 1-2 sentences. No preamble, no code fences." },
                { role = "user", content = prompt },
              },
              temperature = 0.2,
              max_tokens = 160,
              stream = false,
            })
            -- Replies come back as one long line; max_width forces the float to
            -- wrap (it also sets wrap_at) instead of stretching across the screen.
            local float = { border = "rounded", max_width = 60 }
            vim.lsp.util.open_floating_preview({ "Explaining " .. label .. "..." }, "markdown", float)
            vim.system(
              { "curl", "-sS", "--max-time", "30", "http://127.0.0.1:8011/v1/chat/completions",
                "-H", "Content-Type: application/json", "-d", body },
              { text = true },
              function(out)
                local ok, decoded = pcall(vim.json.decode, out.stdout or "")
                local msg
                if ok and decoded.choices and decoded.choices[1] then
                  msg = decoded.choices[1].message.content
                else
                  msg = "llama-server unreachable (is the local-ai service up on :8011?)"
                end
                vim.schedule(function()
                  vim.lsp.util.open_floating_preview(vim.split(vim.trim(msg), "\n"), "markdown", float)
                end)
              end
            )
          end
          package.loaded["llama_explain"] = M
        '';
      };
    };
  };
}
