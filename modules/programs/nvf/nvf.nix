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
    # AI plugins follow the agent selected by this home; absent program units
    # do not declare their enable options, hence attrByPath.
    claudeAi = lib.attrByPath ["programs" "claude-code" "enable"] false config;
    piAi = lib.attrByPath ["programs" "pi" "enable"] false config;
    piAcp = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.pi-acp;
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
        # On NixOS, stylix themes nvf automatically (everforest-dark-hard).
        # The macs have no stylix, so without a colorscheme treesitter has no
        # palette behind it and code looks washed out. Enable the same scheme
        # as a self-contained base16 theme — but only on Darwin, so it never
        # overrides stylix on NixOS. Palette copied verbatim from
        # ${pkgs.base16-schemes}/share/themes/everforest-dark-hard.yaml.
        theme = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          enable = true;
          name = "base16";
          base16-colors = {
            base00 = "#272e33";
            base01 = "#2e383c";
            base02 = "#414b50";
            base03 = "#859289";
            base04 = "#9da9a0";
            base05 = "#d3c6aa";
            base06 = "#edeada";
            base07 = "#fffbef";
            base08 = "#e67e80";
            base09 = "#e69875";
            base0A = "#dbbc7f";
            base0B = "#a7c080";
            base0C = "#83c092";
            base0D = "#7fbbb3";
            base0E = "#d699b6";
            base0F = "#9da9a0";
          };
        };

        # ----------------
        # Global Options
        # ----------------
        # Tab and space settings live in indent.nix, never here.
        options = {
          autoread = true; # Reload buffers when the underlying file changes on disk
          cmdheight = 1; # The height of the command pane in lines
          cursorlineopt = "both"; # The way to highlight the line the cursor is on
          foldlevel = 99; # stops auto folding when opening document
          mouse = "nvi"; # Supported modes for mouse control
          signcolumn = "yes"; # Show the sign column (what is sign column)
          splitbelow = true; # On true new splits open below instead of above
          splitright = true; # New splits will open to the right
          termguicolors = true; # On true use 256 colors for terminal
          tm = 500; # The time in ms that Neovim will wait for the next key in chord
          updatetime = 25; # The number of ms until the cursor hold event is triggered
          wrap = false; # Whether to wrap lines if they go off screen
        };

        assistant.codecompanion-nvim = lib.mkIf piAi {
          enable = true;
          setupOpts = {
            adapters = lib.generators.mkLuaInline ''
              {
                acp = {
                  pi = function()
                    local helpers = require("codecompanion.adapters.acp.helpers")
                    return {
                      name = "pi",
                      formatted_name = "Pi",
                      type = "acp",
                      roles = {
                        llm = "assistant",
                        user = "user",
                      },
                      commands = {
                        default = { "${piAcp}/bin/pi-acp" },
                      },
                      defaults = {
                        mcpServers = {},
                        timeout = 20000,
                      },
                      env = {
                        PI_ACP_ENABLE_EMBEDDED_CONTEXT = "true",
                      },
                      parameters = {
                        protocolVersion = 1,
                        clientCapabilities = {
                          fs = { readTextFile = true, writeTextFile = true },
                        },
                        clientInfo = {
                          name = "CodeCompanion.nvim",
                          version = "1.0.0",
                        },
                      },
                      handlers = {
                        setup = function(self)
                          return true
                        end,
                        auth = function(self)
                          return true
                        end,
                        form_messages = function(self, messages, capabilities)
                          return helpers.form_messages(self, messages, capabilities)
                        end,
                        on_exit = function(self, code) end,
                      },
                    }
                  end,
                  opts = {
                    show_presets = false,
                  },
                },
              }
            '';
            interactions.chat.adapter = "pi";
          };
        };

        # ---------------------------------------
        # Lazy Loading and non-included plugins
        # ---------------------------------------
        lazy = {
          enable = true; # Enable lazy loading for plugins to load in only when needed
          enableLznAutoRequire = true; # Builtin plugins need this, only turn off for debug
          plugins = {
            codecompanion-nvim = lib.mkIf piAi {
              keys = [
                {
                  key = "<leader>at";
                  mode = "n";
                  action = "<cmd>CodeCompanionChat Toggle<cr>";
                  desc = "Toggle Pi chat";
                }
                {
                  key = "<leader>aa";
                  mode = ["n" "v"];
                  action = "<cmd>CodeCompanionActions<cr>";
                  desc = "Pi actions";
                }
                {
                  key = "<leader>as";
                  mode = "v";
                  action = "<cmd>CodeCompanionChat Add<cr>";
                  desc = "Add selection to Pi chat";
                }
              ];
            };

            "claudecode.nvim" = lib.mkIf claudeAi {
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
                  # Same snapshot detour as <leader>as, for the whole buffer.
                  key = "<leader>ab";
                  mode = "n";
                  lua = true;
                  action = ''
                    function()
                      if not vim.api.nvim_buf_get_name(0):match("^codediff://") then
                        vim.cmd("ClaudeCodeAdd %")
                        return
                      end
                      local path = claudecode_codediff_snapshot()
                      if path then
                        require("claudecode").send_at_mention(path, nil, nil, "ClaudeCodeAdd")
                      end
                    end
                  '';
                  desc = "Add current buffer";
                }
                {
                  # A codediff:// revision buffer exists nowhere on disk, so
                  # ClaudeCodeSend's @-mention would fail; mention a snapshot
                  # of it instead (see claudecode_codediff_snapshot).
                  key = "<leader>as";
                  mode = "v";
                  lua = true;
                  action = ''
                    function()
                      if not vim.api.nvim_buf_get_name(0):match("^codediff://") then
                        vim.cmd("ClaudeCodeSend")
                        return
                      end
                      local path, header = claudecode_codediff_snapshot()
                      if not path then return end
                      local s = vim.fn.line("v") + header
                      local e = vim.fn.line(".") + header
                      if s > e then s, e = e, s end
                      -- send_at_mention takes 0-indexed lines
                      require("claudecode").send_at_mention(path, s - 1, e - 1, "ClaudeCodeSend")
                      vim.api.nvim_feedkeys("\27", "n", false)
                    end
                  '';
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

            # jujutsu under <leader>j, mirroring the git <leader>g prefix. Only
            # entry points are bound here; deeper ops (split, rebase, bookmarks,
            # abandon) live as in-buffer keys inside the `:J log` hub.
            "jj.nvim" = {
              package = pkgs.vimPlugins.jj-nvim;
              setupModule = "jj";
              setupOpts = {};
              cmd = ["J" "Jbrowse" "Jdiff" "Jhdiff" "Jvdiff"];
              keys = [
                {
                  key = "<leader>js";
                  mode = "n";
                  action = "<cmd>J status<cr>";
                  desc = "jj status";
                }
                {
                  key = "<leader>jl";
                  mode = "n";
                  action = "<cmd>J log<cr>";
                  desc = "jj log";
                }
                {
                  key = "<leader>jd";
                  mode = "n";
                  action = "<cmd>Jdiff<cr>";
                  desc = "jj diff (vs parent)";
                }
                {
                  key = "<leader>jn";
                  mode = "n";
                  action = "<cmd>J new<cr>";
                  desc = "jj new";
                }
                {
                  key = "<leader>jc";
                  mode = "n";
                  action = "<cmd>J describe<cr>";
                  desc = "jj describe";
                }
                {
                  key = "<leader>je";
                  mode = "n";
                  action = "<cmd>J edit<cr>";
                  desc = "jj edit";
                }
                {
                  key = "<leader>jq";
                  mode = "n";
                  action = "<cmd>J squash<cr>";
                  desc = "jj squash";
                }
                {
                  key = "<leader>ju";
                  mode = "n";
                  action = "<cmd>J undo<cr>";
                  desc = "jj undo";
                }
              ];
            };

            # VSCode-style side-by-side diff viewer (:CodeDiff). In-diff keys
            # ([c/]c hunks, [f/]f files, t layout, q close) are its defaults.
            # Launchers replace gitsigns' plain vimdiff: file-scoped under
            # <leader>gd, project-scoped under <leader>gD.
            "codediff.nvim" = {
              package = pkgs.vimPlugins.codediff-nvim;
              setupModule = "codediff";
              setupOpts = {};
              cmd = ["CodeDiff"];
              keys = [
                {
                  key = "<leader>gdd";
                  mode = "n";
                  action = "<cmd>CodeDiff file HEAD<cr>";
                  desc = "Diff file vs HEAD";
                }
                {
                  key = "<leader>gdh";
                  mode = "n";
                  action = "<cmd>CodeDiff history %<cr>";
                  desc = "File history";
                }
                {
                  key = "<leader>gdb";
                  mode = "n";
                  lua = true;
                  action = ''
                    function()
                      local base = codediff_branch_base()
                      if base then vim.cmd("CodeDiff file " .. base .. "...") end
                    end
                  '';
                  desc = "Diff file vs branch base";
                }
                {
                  # ":" keeps the visual range, which codediff turns into
                  # line-range history (git log -L) for the selection.
                  key = "<leader>gdh";
                  mode = "x";
                  action = ":CodeDiff history<cr>";
                  desc = "History of selected lines";
                }
                {
                  key = "<leader>gDd";
                  mode = "n";
                  action = "<cmd>CodeDiff<cr>";
                  desc = "Diff project vs HEAD";
                }
                {
                  key = "<leader>gDs";
                  mode = "n";
                  action = "<cmd>CodeDiff --staged<cr>";
                  desc = "Diff staged";
                }
                {
                  key = "<leader>gDh";
                  mode = "n";
                  action = "<cmd>CodeDiff history<cr>";
                  desc = "Project history";
                }
                {
                  key = "<leader>gDb";
                  mode = "n";
                  lua = true;
                  action = ''
                    function()
                      local base = codediff_branch_base()
                      if base then vim.cmd("CodeDiff " .. base .. "...") end
                    end
                  '';
                  desc = "Diff branch (vs branch base)";
                }
              ];
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

          helm.enable = true;

          html.enable = true;

          java.enable = true;

          json = {
            enable = true;
            # prettier over jsonfmt, which discovers no project config at all.
            format.type = ["prettier"];
          };

          lua = {
            enable = true;
            extensions.lazydev.enable = true; # Extra config for NeoVim Files
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
            # ruff over black: black hard-codes 4 spaces with no option to
            # follow a project's declared width. Output stays black-compatible.
            format.type = ["ruff"];
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
            # Render in every window, not just the focused one, so both
            # sides of a diff show the header and stay row-aligned
            setupOpts.multiwindow = true;
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

        # -----
        # Git
        # -----
        # gitsigns alone (the rest of the `vim.git` suite stays off): acts on the
        # hunk under the cursor, complementing the repo-browsing pickers above.
        # Mappings moved onto <leader>g so all git shares one prefix.
        git.gitsigns = {
          enable = true;
          mappings = {
            nextHunk = "]c";
            previousHunk = "[c";
            stageHunk = "<leader>gs"; # also visual: stage selected lines
            undoStageHunk = "<leader>gu";
            resetHunk = "<leader>gr"; # also visual: reset selected lines
            stageBuffer = "<leader>gS";
            resetBuffer = "<leader>gR";
            previewHunk = "<leader>gp";
            blameLine = "<leader>gl";
            toggleBlame = "<leader>gt";
            # codediff owns diffing (<leader>gd/<leader>gD prefixes); null
            # stops nvf re-binding these to its <leader>hd/<leader>hD defaults.
            diffThis = null;
            diffProject = null;
            toggleDeleted = "<leader>gT";
          };
        };

        # ----------------------------
        # Snacks (QoL plugin bundle)
        # ----------------------------
        # The picker (file/grep/git/LSP finders, bound in keymaps below) plus
        # claudecode.nvim's recommended terminal provider.
        utility.snacks-nvim = {
          enable = true;
          # In-picker navigation mirroring the global Alt motions. snacks reads a
          # bare string rhs as an action name, so moving the cursor needs a
          # function action; it also binds <a-h> to toggle_hidden by default,
          # which cursor_left/right override.
          setupOpts.picker = let
            feed = k: lib.generators.mkLuaInline "function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('${k}', true, false, true), 'n', false) end";
            key = lib.generators.mkLuaInline;
          in {
            enabled = true;
            sources.files.hidden = true;
            sources.grep.hidden = true;
            actions.cursor_left = feed "<Left>";
            actions.cursor_right = feed "<Right>";
            win.input.keys = {
              "<a-j>" = key ''{ "list_down", mode = { "i", "n" } }'';
              "<a-k>" = key ''{ "list_up", mode = { "i", "n" } }'';
              "<a-J>" = key ''{ "list_scroll_down", mode = { "i", "n" } }'';
              "<a-K>" = key ''{ "list_scroll_up", mode = { "i", "n" } }'';
              "<a-h>" = key ''{ "cursor_left", mode = { "i" } }'';
              "<a-l>" = key ''{ "cursor_right", mode = { "i" } }'';
              # snacks' default <Esc> is normal-mode only, but the picker opens
              # in insert; bind both modes so one press closes it.
              "<esc>" = key ''{ "cancel", mode = { "i", "n" } }'';
            };
          };
        };

        # snacks' pickers shell out to these: ripgrep for grep, fd for file
        # finding. Bundle them into the Neovim wrapper so the editor never
        # depends on $PATH.
        extraPackages = with pkgs; [
          ripgrep
          fd
        ];

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
              # Turn the oil window itself into a terminal, cwd'd to the folder
              # oil is showing. Neovim's :terminal loads into the current window
              # (no split); lcd is window-local so the global cwd is untouched.
              "t" = lib.generators.mkLuaInline ''
                {
                  callback = function()
                    local dir = require("oil").get_current_dir()
                    if dir then
                      vim.cmd.lcd({ dir })
                      vim.cmd.terminal()
                      vim.cmd.startinsert()
                    end
                  end,
                  desc = "Open a terminal in this window",
                  mode = "n",
                }
              '';
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

            # Name the key groups so prefixes show a label instead of "+prefix".
            spec =
              lib.optional claudeAi (lib.generators.mkLuaInline ''{ "<leader>a", group = "AI/Claude Code" }'')
              ++ lib.optional piAi (lib.generators.mkLuaInline ''{ "<leader>a", group = "AI/Pi" }'')
              ++ [
                (lib.generators.mkLuaInline ''{ "<leader>f", group = "Find" }'')
                (lib.generators.mkLuaInline ''{ "<leader>g", group = "Git" }'')
                (lib.generators.mkLuaInline ''{ "<leader>gd", group = "Diff (file)" }'')
                (lib.generators.mkLuaInline ''{ "<leader>gD", group = "Diff (project)" }'')
                (lib.generators.mkLuaInline ''{ "<leader>j", group = "Jujutsu" }'')
              ];
          };
        };

        # ---------------
        # Other keymaps
        # ---------------
        keymaps = [
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
          # As above, but add Shift to move the window instead of focusing it.
          {
            key = "<C-S-h>";
            mode = "n";
            action = "<C-w>H";
            desc = "Move window left";
          }
          {
            key = "<C-S-j>";
            mode = "n";
            action = "<C-w>J";
            desc = "Move window down";
          }
          {
            key = "<C-S-k>";
            mode = "n";
            action = "<C-w>K";
            desc = "Move window up";
          }
          {
            key = "<C-S-l>";
            mode = "n";
            action = "<C-w>L";
            desc = "Move window right";
          }
          {
            key = "<C-S-h>";
            mode = "t";
            action = "<C-\\><C-n><C-w>H";
            desc = "Move window left";
          }
          {
            key = "<C-S-j>";
            mode = "t";
            action = "<C-\\><C-n><C-w>J";
            desc = "Move window down";
          }
          {
            key = "<C-S-k>";
            mode = "t";
            action = "<C-\\><C-n><C-w>K";
            desc = "Move window up";
          }
          {
            key = "<C-S-l>";
            mode = "t";
            action = "<C-\\><C-n><C-w>L";
            desc = "Move window right";
          }
          # You resize while staying in the window, so unlike focus/move these
          # use <cmd> (one mode-preserving entry) instead of the <C-\><C-n>
          # break-out — terminal typing keeps working.
          {
            key = "<C-A-h>";
            mode = ["n" "t"];
            action = "<cmd>vertical resize -2<cr>";
            desc = "Shrink window width";
          }
          {
            key = "<C-A-j>";
            mode = ["n" "t"];
            action = "<cmd>resize -2<cr>";
            desc = "Shrink window height";
          }
          {
            key = "<C-A-k>";
            mode = ["n" "t"];
            action = "<cmd>resize +2<cr>";
            desc = "Grow window height";
          }
          {
            key = "<C-A-l>";
            mode = ["n" "t"];
            action = "<cmd>vertical resize +2<cr>";
            desc = "Grow window width";
          }
          # Ctrl+; drops terminal-insert into terminal-normal in place (to
          # scroll/copy), without the window jump the <C-hjkl> maps do. Needs
          # the kitty keyboard protocol to encode Ctrl+;, which Ghostty speaks.
          {
            key = "<C-;>";
            mode = "t";
            action = "<C-\\><C-n>";
            desc = "Exit terminal mode";
          }
          {
            key = "-";
            mode = "n";
            action = "<cmd>Oil<cr>";
            desc = "Open oil (parent directory)";
          }
          # Same as `-`, but from any mode. <cmd> runs :Oil without changing
          # mode, so insert and terminal mode work without a break-out chord.
          {
            key = "<A-->";
            mode = ["n" "i" "v" "t"];
            action = "<cmd>Oil<cr>";
            desc = "Open oil (parent directory), any mode";
          }
          {
            # Turn the current window into a terminal from any mode, always
            # cwd'd to the base dir. getcwd(-1, -1) reads the global cwd (the
            # base, set by <A-b>), ignoring any window-local :lcd drift. (oil's
            # `t` opens in oil's dir.)
            key = "<A-t>";
            mode = ["n" "i" "v" "t"];
            lua = true;
            action = ''
              function()
                vim.cmd.lcd({ vim.fn.getcwd(-1, -1) })
                vim.cmd.terminal()
                vim.cmd.startinsert()
              end
            '';
            desc = "Open a terminal in this window (base dir), any mode";
          }
          {
            # Set the base dir (global :cd, what <A-t> opens in) to "here":
            # oil's folder, a terminal's live cwd (tracked via OSC 7 below), or
            # the current file's folder. notify since a cwd change is invisible.
            key = "<A-b>";
            mode = ["n" "i" "v" "t"];
            lua = true;
            action = ''
              function()
                local dir
                if vim.bo.filetype == "oil" then
                  dir = require("oil").get_current_dir()
                elseif vim.bo.buftype == "terminal" then
                  dir = vim.b.osc7_dir
                elseif vim.api.nvim_buf_get_name(0) ~= "" then
                  dir = vim.fn.expand("%:p:h")
                end
                if dir and vim.fn.isdirectory(dir) == 1 then
                  vim.cmd.cd({ dir })
                  vim.notify("base dir → " .. dir)
                else
                  vim.notify("couldn't determine a directory here", vim.log.levels.WARN)
                end
              end
            '';
            desc = "Set the base dir to here (oil / terminal / file), any mode";
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
          # -----------------------------------
          # Alt+hjkl: move the cursor, any mode
          # -----------------------------------
          # Insert mode uses arrows so the cursor moves without leaving insert.
          # Needs Ghostty's macos-option-as-alt to deliver Option as Alt.
          {
            key = "<A-h>";
            mode = ["n" "x" "o"];
            action = "h";
            desc = "Move cursor left";
          }
          {
            key = "<A-j>";
            mode = ["n" "x" "o"];
            action = "j";
            desc = "Move cursor down";
          }
          {
            key = "<A-k>";
            mode = ["n" "x" "o"];
            action = "k";
            desc = "Move cursor up";
          }
          {
            key = "<A-l>";
            mode = ["n" "x" "o"];
            action = "l";
            desc = "Move cursor right";
          }
          {
            key = "<A-h>";
            mode = "i";
            action = "<Left>";
            desc = "Move cursor left";
          }
          {
            key = "<A-j>";
            mode = "i";
            action = "<Down>";
            desc = "Move cursor down";
          }
          {
            key = "<A-k>";
            mode = "i";
            action = "<Up>";
            desc = "Move cursor up";
          }
          {
            key = "<A-l>";
            mode = "i";
            action = "<Right>";
            desc = "Move cursor right";
          }
          # ---------------------------------------
          # Alt+Shift+j/k: half-page scroll down/up
          # ---------------------------------------
          # Uppercase <A-J>/<A-K> is the robust notation for an Alt+shifted
          # letter. noremap (nvf's default) keeps the <C-d>/<C-u> RHS bound to
          # builtin scroll even though both are disabled just below.
          {
            key = "<A-J>";
            mode = ["n" "x"];
            action = "<C-d>";
            desc = "Half page down";
          }
          {
            key = "<A-K>";
            mode = ["n" "x"];
            action = "<C-u>";
            desc = "Half page up";
          }
          # Insert mode: <C-o> runs one builtin scroll and returns to insert,
          # so typing isn't interrupted (like the Alt+hjkl insert maps above).
          {
            key = "<A-J>";
            mode = "i";
            action = "<C-o><C-d>";
            desc = "Half page down";
          }
          {
            key = "<A-K>";
            mode = "i";
            action = "<C-o><C-u>";
            desc = "Half page up";
          }
          # Terminal mode: break out to terminal-normal first (like the window
          # focus/move maps) — scrollback can't move while the job has focus.
          {
            key = "<A-J>";
            mode = "t";
            action = "<C-\\><C-n><C-d>";
            desc = "Half page down";
          }
          {
            key = "<A-K>";
            mode = "t";
            action = "<C-\\><C-n><C-u>";
            desc = "Half page up";
          }
          # Drop the builtin Ctrl+d/Ctrl+u scroll in normal/visual only, so
          # insert-mode Ctrl+u/Ctrl+d editing is left alone.
          {
            key = "<C-d>";
            mode = ["n" "x"];
            action = "<Nop>";
            desc = "Disabled (half page is Alt+Shift+j)";
          }
          {
            key = "<C-u>";
            mode = ["n" "x"];
            action = "<Nop>";
            desc = "Disabled (half page is Alt+Shift+k)";
          }

          # --------------------------------
          # Snacks pickers (Find <leader>f)
          # --------------------------------
          # The `Snacks` global is available once the picker is enabled above.
          {
            key = "<leader>ff";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.files() end'';
            desc = "Find files";
          }
          {
            key = "<leader>fg";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.grep() end'';
            desc = "Grep";
          }
          {
            key = "<leader>fb";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.buffers() end'';
            desc = "Buffers";
          }
          {
            key = "<leader>fh";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.help() end'';
            desc = "Help tags";
          }
          {
            key = "<leader>fd";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.diagnostics() end'';
            desc = "Diagnostics";
          }
          {
            key = "<leader>fr";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.lsp_references() end'';
            desc = "LSP references";
          }
          {
            key = "<leader>fD";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.lsp_definitions() end'';
            desc = "LSP definitions";
          }

          # ----------------------------------
          # Snacks git pickers (Git <leader>g)
          # ----------------------------------
          # On the <leader>g prefix alongside gitsigns, so all git shares it.
          {
            key = "<leader>gf";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.git_files() end'';
            desc = "Git files";
          }
          {
            key = "<leader>gc";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.git_log() end'';
            desc = "Git commits";
          }
          {
            key = "<leader>gC";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.git_log_file() end'';
            desc = "Git buffer commits";
          }
          {
            key = "<leader>gB";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.git_branches() end'';
            desc = "Git branches";
          }
          {
            key = "<leader>go";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.git_status() end'';
            desc = "Git status";
          }
          {
            key = "<leader>gx";
            mode = ["n"];
            lua = true;
            action = ''function() Snacks.picker.git_stash() end'';
            desc = "Git stash";
          }

          # First/last hunk, completing gitsigns' ]c/[c; here because nvf's
          # gitsigns mappings options have no first/last variant.
          {
            key = "[C";
            mode = ["n"];
            lua = true;
            action = ''function() require("gitsigns").nav_hunk("first") end'';
            desc = "First git hunk";
          }
          {
            key = "]C";
            mode = ["n"];
            lua = true;
            action = ''function() require("gitsigns").nav_hunk("last") end'';
            desc = "Last git hunk";
          }
        ];

        # Track each terminal's live cwd from the OSC 7 sequence the shell emits
        # (fish/Ghostty do) into a per-buffer osc7_dir, so <A-b> can :cd to it.
        luaConfigRC.captureTerminalCwd = ''
          vim.api.nvim_create_autocmd("TermRequest", {
            desc = "Track terminal cwd via OSC 7 (for <A-b>)",
            callback = function(ev)
              local dir = ev.data.sequence:match("\027]7;file://[^/]*(/.*)$")
              if not dir then return end
              dir = dir:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
              if vim.fn.isdirectory(dir) == 1 then vim.b[ev.buf].osc7_dir = dir end
            end,
          })
        '';

        # Branch base for the codediff "diff branch" keys: the trunk the remote
        # points origin/HEAD at, falling back to a local main/master. Runs in
        # Neovim's cwd, matching how codediff itself resolves the working repo.
        luaConfigRC.codediffBranchBase = ''
          function codediff_branch_base()
            local ref = vim.fn.systemlist("git symbolic-ref -q --short refs/remotes/origin/HEAD")[1]
            if vim.v.shell_error == 0 and ref and ref ~= "" then
              return ref
            end
            for _, branch in ipairs({ "main", "master" }) do
              vim.fn.systemlist("git rev-parse -q --verify " .. branch)
              if vim.v.shell_error == 0 then
                return branch
              end
            end
            vim.notify("no branch base found (origin/HEAD, main, master)", vim.log.levels.WARN)
          end
        '';

        # claudecode @-mentions are paths the Claude CLI reads from disk, so a
        # codediff:// revision buffer (history diff, or the base side of any
        # diff) has nothing to mention. Snapshot such a buffer to a read-only
        # session-temp file — labeled historical by a header comment and by its
        # directory name — for the <leader>as/<leader>ab overrides to mention
        # instead. Returns the path and the header line count, or nil if the
        # buffer name does not parse.
        luaConfigRC.claudecodeCodediffSnapshot = ''
          function claudecode_codediff_snapshot()
            local bufname = vim.api.nvim_buf_get_name(0)
            local _, commit, filepath = require("codediff.core.virtual_file").parse_url(bufname)
            if not commit then
              vim.notify("cannot parse codediff buffer: " .. bufname, vim.log.levels.ERROR)
              return nil
            end
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            local header = 0
            if vim.bo.commentstring ~= "" then
              local note = ("read-only git-history snapshot of %s at revision %s; do not edit"):format(filepath, commit)
              table.insert(lines, 1, vim.bo.commentstring:format(note))
              header = 1
            end
            local dir = vim.fn.tempname() .. "/read-only-git-history"
            vim.fn.mkdir(dir, "p")
            local rev = commit:gsub("%W", ""):sub(1, 8)
            local name = vim.fn.fnamemodify(filepath, ":t"):gsub("^[^.]*", "%0@" .. rev, 1)
            local path = dir .. "/" .. name
            vim.fn.writefile(lines, path)
            vim.fn.setfperm(path, "r--r--r--")
            return path, header
          end
        '';

        # autoread only permits a reload; something still has to poll the disk
        # with :checktime. Without this, an external edit (e.g. from Claude
        # Code) leaves the buffer — and LSP diagnostics/hover/go-to-def, which
        # only refresh on didChange — stale.
        luaConfigRC.checktimeOnFocus = ''
          vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
            callback = function()
              if vim.bo.buftype == "" then vim.cmd("checktime") end
            end,
          })
        '';
      };
    };
  };
}
