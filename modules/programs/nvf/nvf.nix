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
    # the system level via hostConstants (see modules/host-config/roles/local-ai).
    localAi = config.hostConstants.localAi;

    # Which AI agent plugin this home gets, read from the sibling program
    # state in the same home config. The enable options only exist in homes
    # that import the generated program unit, hence attrByPath. oh-my-pi wins
    # if both are somehow enabled; a home with neither gets no AI plugin.
    ompAi = lib.attrByPath ["programs" "oh-my-pi" "enable"] false config;
    claudeAi = !ompAi && lib.attrByPath ["programs" "claude-code" "enable"] false config;
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
          autoread = true; # Reload buffers when the underlying file changes on disk
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
            # (claude-code homes only; oh-my-pi homes get codecompanion).
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

            # codecompanion.nvim: chat with the omp coding agent over ACP
            # (oh-my-pi homes only; claude-code homes get claudecode.nvim
            # above). omp routes edits through ACP's session/request_permission
            # and owns auth (~/.omp/agent/agent.db), so nvim holds no API key.
            #
            # No inline-assistant keymap: codecompanion's inline interaction
            # supports HTTP adapters only, not ACP (interactions/inline).
            "codecompanion.nvim" = lib.mkIf ompAi {
              package = pkgs.vimPlugins.codecompanion-nvim;
              setupModule = "codecompanion";
              setupOpts = {
                # Custom ACP adapter running `omp acp`. Extending the shipped
                # claude_code ACP adapter inherits its protocol plumbing
                # (form_messages etc.); the auth override is required — the
                # inherited handler fails without CLAUDE_CODE_OAUTH_TOKEN, and
                # omp needs no token from the editor.
                adapters.acp.omp = lib.generators.mkLuaInline ''
                  function()
                    return require("codecompanion.adapters").extend("claude_code", {
                      name = "omp",
                      formatted_name = "oh-my-pi",
                      commands = {
                        default = { "omp", "acp" },
                        yolo = { "omp", "acp" },
                      },
                      handlers = {
                        auth = function() return true end,
                      },
                    })
                  end
                '';
                interactions.chat.adapter = "omp";
              };
              cmd = [
                "CodeCompanion"
                "CodeCompanionChat"
                "CodeCompanionActions"
                "CodeCompanionCmd"
              ];

              keys = [
                {
                  key = "<leader>at";
                  mode = "n";
                  action = "<cmd>CodeCompanionChat Toggle<cr>";
                  desc = "Toggle CodeCompanion";
                }
                {
                  # Jump to the last chat's window, reopening it if hidden;
                  # restore() focuses a visible chat instead of toggling it.
                  key = "<leader>af";
                  mode = "n";
                  lua = true;
                  action = ''
                    function()
                      local cc = require("codecompanion")
                      local chat = cc.last_chat()
                      if chat then cc.restore(chat.bufnr) else cc.chat() end
                    end
                  '';
                  desc = "Focus CodeCompanion chat";
                }
                {
                  # Open a fresh chat and run the /resume slash command (ACP
                  # session/list + session/load — a picker of past omp
                  # sessions). The ACP connection is created asynchronously
                  # when the chat opens, so poll briefly until it's up.
                  key = "<leader>ar";
                  mode = "n";
                  lua = true;
                  action = ''
                    function()
                      local chat = require("codecompanion").chat()
                      if not chat then return end
                      local tries = 0
                      local function attempt()
                        if chat.acp_connection then
                          require("codecompanion.interactions.chat.slash_commands").new():execute({
                            label = "resume",
                            config = require("codecompanion.config").interactions.chat.slash_commands.resume,
                          }, chat)
                        elseif tries < 50 then
                          tries = tries + 1
                          vim.defer_fn(attempt, 100)
                        else
                          vim.notify("omp ACP connection not ready; try /resume in the chat", vim.log.levels.WARN)
                        end
                      end
                      attempt()
                    end
                  '';
                  desc = "Resume an omp session";
                }
                {
                  # ACP model picker (session-scoped): get_models() over the
                  # live connection, then change_model on selection.
                  key = "<leader>am";
                  mode = "n";
                  lua = true;
                  action = ''
                    function()
                      local chat = require("codecompanion").last_chat()
                      if not (chat and chat.acp_connection) then
                        return vim.notify("No active CodeCompanion chat", vim.log.levels.WARN)
                      end
                      require("codecompanion.interactions.chat.keymaps.change_adapter").select_model(chat)
                    end
                  '';
                  desc = "Select omp model";
                }
                {
                  # Capture the path before touching the chat — creating or
                  # focusing it changes the current buffer.
                  key = "<leader>ab";
                  mode = "n";
                  lua = true;
                  action = ''
                    function()
                      local path = vim.api.nvim_buf_get_name(0)
                      if path == "" then
                        return vim.notify("No file for this buffer", vim.log.levels.WARN)
                      end
                      local cc = require("codecompanion")
                      local chat = cc.last_chat() or cc.chat()
                      if not chat then return end
                      require("codecompanion.interactions.chat.slash_commands").context(chat, "file", {
                        path = path,
                        description = "Added from <leader>ab",
                      })
                    end
                  '';
                  desc = "Add current buffer";
                }
                {
                  key = "<leader>as";
                  mode = "v";
                  action = "<cmd>CodeCompanionChat Add<cr>";
                  desc = "Send to CodeCompanion";
                }
                {
                  # In oil, <leader>as adds the file under the cursor instead
                  # of sending a selection (oil is this config's file
                  # explorer; codecompanion has no tree integration of its
                  # own, so resolve the path via oil's API).
                  key = "<leader>as";
                  mode = "n";
                  ft = ["oil"];
                  lua = true;
                  action = ''
                    function()
                      local oil = require("oil")
                      local entry = oil.get_cursor_entry()
                      local dir = oil.get_current_dir()
                      if not (entry and dir and entry.type == "file") then
                        return vim.notify("No file under cursor", vim.log.levels.WARN)
                      end
                      local cc = require("codecompanion")
                      local chat = cc.last_chat() or cc.chat()
                      if not chat then return end
                      require("codecompanion.interactions.chat.slash_commands").context(chat, "file", {
                        path = dir .. entry.name,
                        description = "Added from oil",
                      })
                    end
                  '';
                  desc = "Add file";
                }
                {
                  key = "<leader>aa";
                  mode = "n";
                  action = "<cmd>CodeCompanionActions<cr>";
                  desc = "CodeCompanion actions";
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
            diffThis = "<leader>gd";
            diffProject = "<leader>gD";
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
            # The <leader>a label follows the home's AI plugin; a home with
            # neither agent registers no group.
            spec =
              lib.optional claudeAi (lib.generators.mkLuaInline ''{ "<leader>a", group = "AI/Claude Code" }'')
              ++ lib.optional ompAi (lib.generators.mkLuaInline ''{ "<leader>a", group = "AI/CodeCompanion" }'')
              ++ [
                (lib.generators.mkLuaInline ''{ "<leader>f", group = "Find" }'')
                (lib.generators.mkLuaInline ''{ "<leader>g", group = "Git" }'')
                (lib.generators.mkLuaInline ''{ "<leader>j", group = "Jujutsu" }'')
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
          ]
          # Local AI hovers (see luaConfigRC below), joining the existing
          # <leader>a "AI/Claude Code" which-key group. ak/aq act on the symbol
          # under the cursor (or the visual selection); ah is a global config
          # query with no cursor context.
          ++ lib.optionals localAi [
            {
              key = "<leader>ak";
              mode = ["n"];
              lua = true;
              action = ''function() require("llama_explain").explain() end'';
              desc = "Explain symbol (local AI)";
            }
            {
              key = "<leader>ak";
              mode = ["x"];
              lua = true;
              action = ''function() require("llama_explain").explain_visual() end'';
              desc = "Explain selection (local AI)";
            }
            {
              key = "<leader>aq";
              mode = ["n"];
              lua = true;
              action = ''function() require("llama_explain").ask() end'';
              desc = "Ask about symbol (local AI)";
            }
            {
              key = "<leader>aq";
              mode = ["x"];
              lua = true;
              action = ''function() require("llama_explain").ask_visual() end'';
              desc = "Ask about selection (local AI)";
            }
            {
              key = "<leader>ah";
              mode = ["n"];
              lua = true;
              action = ''function() require("llama_explain").how() end'';
              desc = "How do I…? (local AI)";
            }
          ];

        # Local AI hovers, shown in the same float style as the LSP `K` hover.
        # `explain` summarizes the code; `ask` answers a typed question about it.
        # Both target the visual selection, else the symbol under the cursor, and
        # feed the model the whole file plus the LSP-resolved definition of the
        # symbol (which may live in another file) so its answers aren't blind to
        # the rest of the code. `how` instead feeds the editor's live keymaps and
        # commands and answers a plain-language "how do I…?" config question. The
        # HTTP call is async (vim.system) so it never blocks; the one short
        # definition lookup is sync. Exposed as the llama_explain module the
        # keymaps above require.
        luaConfigRC.llamaExplain = lib.mkIf localAi ''
          local M = {}

          -- POST a chat completion to the local instruct server and render the
          -- reply in a float. Replies come back as one long line; max_width
          -- forces the float to wrap (it also sets wrap_at) instead of
          -- stretching across the screen.
          local function chat(system, user, placeholder)
            local body = vim.json.encode({
              messages = {
                { role = "system", content = system },
                { role = "user", content = user },
              },
              temperature = 0.2,
              max_tokens = 512,
              stream = false,
            })
            local float = { border = "rounded", max_width = 60 }
            vim.lsp.util.open_floating_preview({ placeholder }, "markdown", float)
            vim.system(
              { "curl", "-sS", "--max-time", "30", "http://127.0.0.1:8011/v1/chat/completions",
                "-H", "Content-Type: application/json", "-d", body },
              { text = true },
              function(out)
                local ok, decoded = pcall(vim.json.decode, out.stdout or "")
                local msg = (ok and decoded.choices and decoded.choices[1])
                  and decoded.choices[1].message.content
                  or "llama-server unreachable (is the local-ai service up on :8011?)"
                vim.schedule(function()
                  vim.lsp.util.open_floating_preview(vim.split(vim.trim(msg), "\n"), "markdown", float)
                end)
              end
            )
          end

          -- Capture the highlighted text. Called only from the visual-mode maps,
          -- so the marks are live; reads `mode` only for getregion's type.
          local function selection()
            local mode = vim.fn.mode()
            local region = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
            -- Leave visual mode so the highlight doesn't linger behind the float.
            vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
            return table.concat(region, "\n")
          end

          -- Resolve one LSP definition location to a labeled snippet. The target
          -- often lives elsewhere (stdlib, for `Vec`/`Arc`); read it straight from
          -- disk, not via a buffer — loading a not-yet-open file can invalidate
          -- that buffer before we read it, which crashed `explain`.
          local function read_def(word, uri, range)
            local path = vim.uri_to_fname(uri)
            local from = range.start.line
            local lines = {}
            -- readfile errors on an unreadable path, so guard it.
            if vim.fn.filereadable(path) == 1 then
              lines = vim.list_slice(vim.fn.readfile(path, "", from + 30), from + 1, from + 30)
            end
            local src = table.concat(lines, "\n")
            local rel = vim.fn.fnamemodify(path, ":.")
            return path .. ":" .. from, "### `" .. word .. "` (" .. rel .. ":" .. (from + 1) .. ")\n" .. src
          end

          -- Ask the running language server where the symbol under the cursor is
          -- defined and return its source (deduped), or nil. This is the
          -- "open other files for context" piece — reuse the LSP, don't grep.
          local function definitions(word, pos)
            if vim.tbl_isempty(vim.lsp.get_clients({ bufnr = 0 })) then return nil end
            local params = {
              textDocument = { uri = vim.uri_from_bufnr(0) },
              position = { line = pos[1] - 1, character = pos[2] },
            }
            local res = vim.lsp.buf_request_sync(0, "textDocument/definition", params, 200)
            if not res then return nil end
            local out, seen = {}, {}
            for _, r in pairs(res) do
              local result = r.result or {}
              -- a single Location/LocationLink, or a list of them
              if result.uri or result.targetUri then result = { result } end
              for _, loc in ipairs(result) do
                local uri = loc.uri or loc.targetUri
                local range = loc.range or loc.targetSelectionRange or loc.targetRange
                if uri and range then
                  local key, snippet = read_def(word, uri, range)
                  if not seen[key] then
                    seen[key] = true
                    out[#out + 1] = snippet
                  end
                end
              end
            end
            return #out > 0 and table.concat(out, "\n\n") or nil
          end

          -- The whole buffer, so the model can see beyond the snippet. Bounded to
          -- ~±100 lines around the cursor for big files so we don't blow the
          -- server's context window.
          local function file_context()
            local n = vim.api.nvim_buf_line_count(0)
            local from, to = 0, n
            if n > 400 then
              local row = vim.api.nvim_win_get_cursor(0)[1]
              from, to = math.max(0, row - 100), math.min(n, row + 100)
            end
            local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
            return path, table.concat(vim.api.nvim_buf_get_lines(0, from, to, false), "\n")
          end

          -- Build the context block both commands share: the focus (the given
          -- selection, else the word under the cursor with nearby lines), the
          -- whole file, and the symbol's definition. `sel` is the visual
          -- selection (visual maps) or nil (normal maps). Returns (blob, label),
          -- or nil if there's nothing to focus on.
          local function gather(sel)
            local pos = vim.api.nvim_win_get_cursor(0)
            local word = vim.fn.expand("<cword>")
            local defs = word ~= "" and definitions(word, pos) or nil
            local focus, label
            if sel and sel ~= "" then
              focus, label = sel, "selection"
            elseif word ~= "" then
              local near = table.concat(vim.fn.getline(math.max(1, pos[1] - 8), pos[1] + 8), "\n")
              focus, label = "`" .. word .. "`\n" .. near, word
            else
              return nil
            end
            local path, file = file_context()
            local blob = "Focus on this " .. vim.bo.filetype .. " code:\n" .. focus
              .. "\n\nFull file (" .. path .. "):\n" .. file
              .. "\n\nDefinition of the symbol under the cursor:\n" .. (defs or "(none found)")
            return blob, label
          end

          local explainer = "You are a code explainer. Be concise. No preamble, no code fences."

          -- <leader>ak: explain the focus — its purpose and reasoning (why), not
          -- a line-by-line description.
          function M.explain(sel)
            local blob, label = gather(sel)
            if not blob then vim.notify("No symbol under cursor", vim.log.levels.WARN) return end
            chat(explainer,
              "Explain WHY the focused code does what it does — its purpose and reasoning, not a line-by-line description.\n\n" .. blob,
              "Explaining " .. label .. "...")
          end

          -- <leader>aq: prompt for a free-form question about the focus; answer
          -- renders in the same float.
          function M.ask(sel)
            local blob, label = gather(sel)
            if not blob then vim.notify("No symbol under cursor", vim.log.levels.WARN) return end
            vim.ui.input({ prompt = "Ask about this code: " }, function(question)
              if not question or question == "" then return end
              chat("You are a code assistant. Answer the question concisely. No preamble, no code fences.",
                question .. "\n\n" .. blob,
                "Asking...")
            end)
          end

          -- Visual-mode entry points: capture the selection (while still in
          -- visual mode) and hand it to the normal command.
          function M.explain_visual() M.explain(selection()) end
          function M.ask_visual() M.ask(selection()) end

          -- Labeled keymaps (global + current buffer) as model context, deduped
          -- by (mode, lhs). keytrans turns the internal lhs back into readable
          -- form (a literal space becomes <Space>). Skip maps with no desc: they
          -- are plumbing the user wouldn't ask for by name.
          local function keymap_corpus()
            local out, seen = {}, {}
            for _, mode in ipairs({ "n", "i", "v", "x", "t" }) do
              local maps = vim.api.nvim_get_keymap(mode)
              vim.list_extend(maps, vim.api.nvim_buf_get_keymap(0, mode))
              for _, m in ipairs(maps) do
                local key = vim.fn.keytrans(m.lhsraw or m.lhs)
                local id = mode .. "\t" .. key
                if m.desc and m.desc ~= "" and not seen[id] then
                  seen[id] = true
                  out[#out + 1] = key .. " (" .. mode .. ") — " .. m.desc
                end
              end
            end
            return table.concat(out, "\n")
          end

          -- Ex commands (global + current buffer) as model context. Both APIs
          -- return a name-keyed dict, so merge by key rather than concat.
          local function command_corpus()
            local cmds = vim.api.nvim_get_commands({})
            cmds = vim.tbl_extend("force", cmds, vim.api.nvim_buf_get_commands(0, {}))
            local out = {}
            for name, c in pairs(cmds) do
              local def = c.definition and vim.trim(c.definition) or ""
              out[#out + 1] = def ~= "" and (":" .. name .. " — " .. def) or (":" .. name)
            end
            table.sort(out)
            return table.concat(out, "\n")
          end

          -- Answer "how do I…?" from the keymap/command corpus instead of cursor
          -- context: a global config question, so it names the binding(s) to use.
          function M.how()
            local keymaps, commands = keymap_corpus(), command_corpus()
            vim.ui.input({ prompt = "How do I…? " }, function(q)
              if not q or q == "" then return end
              chat(
                "You are an assistant for this configured Neovim. Given the question and the"
                  .. " editor's keymaps and commands below, name the exact keymap(s)/command(s) that"
                  .. " do it, quoting the precise keys (e.g. <leader>e) or command (e.g. :Oil)."
                  .. " Prefer the user's configured bindings; fall back to standard Neovim only when"
                  .. " nothing configured fits. Be concise. No preamble, no code fences.",
                q .. "\n\nKeymaps:\n" .. keymaps .. "\n\nCommands:\n" .. commands,
                "Searching the config…")
            end)
          end

          package.loaded["llama_explain"] = M
        '';

        # llama.vim attaches its FIM ghost text to every insert-mode buffer,
        # including the snacks picker prompt, where autocomplete makes no sense
        # (and cursor motions appear to "accept" it). Disable llama while a picker
        # prompt is focused and restore it once the picker closes.
        #
        # llama lazy-loads on InsertEnter (via lz.n), so it isn't defined at
        # FileType time. Hook the prompt's own InsertEnter instead: lz.n's loader
        # autocmd is registered at startup, so it runs (and loads llama) before
        # this one, created later at FileType. exists() still guards the gap.
        luaConfigRC.llamaPicker = lib.mkIf localAi ''
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "snacks_picker_input",
            callback = function(ev)
              vim.api.nvim_create_autocmd("InsertEnter", {
                buffer = ev.buf,
                callback = function()
                  if vim.fn.exists("*llama#disable") == 1 then vim.fn["llama#disable"]() end
                end,
              })
              vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout" }, {
                buffer = ev.buf,
                once = true,
                callback = function()
                  if vim.fn.exists("*llama#enable") == 1 then vim.fn["llama#enable"]() end
                end,
              })
            end,
          })
        '';

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
