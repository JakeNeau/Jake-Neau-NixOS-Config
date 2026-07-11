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
    # Which AI agent plugin this home gets, read from the sibling program
    # state in the same home config. The enable options only exist in homes
    # that import the generated program unit, hence attrByPath. oh-my-pi wins
    # if both are somehow enabled; a home with neither gets no AI plugin.
    ompAi = lib.attrByPath ["programs" "oh-my-pi" "enable"] false config;
    claudeAi = !ompAi && lib.attrByPath ["programs" "claude-code" "enable"] false config;

    # The omp prompts point the agent at this config's source; the repo root
    # differs per platform, so bake it in at build time.
    repoRoot =
      if pkgs.stdenv.isDarwin
      then "/etc/nix-darwin"
      else "/etc/nixos";
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

                # The ak/aq/ah shortcut ports (see their keymaps below). The
                # content functions work from the captured buffer context, not
                # the live cursor — they may run after focus moved to the chat
                # — via the codecompanion_prompts helpers in luaConfigRC.
                prompt_library = {
                  "Explain why" = {
                    interaction = "chat";
                    description = "Explain the focused code — purpose and reasoning";
                    opts = {
                      alias = "why";
                      auto_submit = true;
                    };
                    prompts = [
                      {
                        role = "user";
                        content = lib.generators.mkLuaInline ''
                          function(context)
                            return "Explain WHY the focused code does what it does — its purpose and reasoning, not a line-by-line description.\n\nFocus on "
                              .. require("codecompanion_prompts").focus(context)
                          end
                        '';
                      }
                    ];
                  };

                  # user_prompt: vim.ui.input collects the question, which
                  # joins the chat as the final user message.
                  "Ask about this code" = {
                    interaction = "chat";
                    description = "Ask a free-form question about the focused code";
                    opts = {
                      alias = "ask";
                      auto_submit = true;
                      user_prompt = true;
                    };
                    prompts = [
                      {
                        role = "user";
                        content = lib.generators.mkLuaInline ''
                          function(context)
                            return "Answer the question that follows about "
                              .. require("codecompanion_prompts").focus(context)
                          end
                        '';
                      }
                    ];
                  };

                  # Feeds the editor's live keymap/command corpus (runtime
                  # truth beats reading config) plus a pointer to the config
                  # source, which the omp agent can read/grep itself.
                  "How do I…?" = {
                    interaction = "chat";
                    description = "How do I…? — answered from this editor's keymaps and commands";
                    opts = {
                      alias = "how";
                      auto_submit = true;
                      user_prompt = true;
                    };
                    prompts = [
                      {
                        role = "user";
                        content = lib.generators.mkLuaInline ''
                          function(context)
                            local p = require("codecompanion_prompts")
                            return "Answer the \"how do I…?\" question that follows using this configured Neovim's own keymaps and commands: name the exact keymap(s)/command(s) that do it, quoting the precise keys (e.g. <leader>e) or command (e.g. :Oil). Prefer the configured bindings; fall back to standard Neovim only when nothing configured fits."
                              .. " The editor's config source lives at ${repoRoot}/modules/programs/nvf/nvf.nix — read or grep it when the corpus below isn't enough."
                              .. "\n\nKeymaps:\n" .. p.keymap_corpus(context.bufnr)
                              .. "\n\nCommands:\n" .. p.command_corpus(context.bufnr)
                          end
                        '';
                      }
                    ];
                  };
                };
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
                # The prompt-library ports (prompt_library above). The `:`
                # form (not <cmd>) so a visual selection passes its range to
                # the command, which is how the prompt sees the selection.
                {
                  key = "<leader>ak";
                  mode = ["n" "x"];
                  action = ":CodeCompanion /why<cr>";
                  desc = "Explain why (omp)";
                }
                {
                  key = "<leader>aq";
                  mode = ["n" "x"];
                  action = ":CodeCompanion /ask<cr>";
                  desc = "Ask about this code (omp)";
                }
                {
                  key = "<leader>ah";
                  mode = "n";
                  action = ":CodeCompanion /how<cr>";
                  desc = "How do I…? (omp)";
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
        ];

        # Helpers behind the codecompanion prompt-library entries (oh-my-pi
        # homes only): the focused-code block the why/ask prompts share, and
        # the live keymap/command corpora the how prompt feeds the agent.
        # Exposed as the codecompanion_prompts module the prompt content
        # functions require.
        luaConfigRC.codecompanionPrompts = lib.mkIf ompAi ''
          local M = {}

          -- The focused code: the visual selection, else the symbol under the
          -- cursor shown with nearby lines. Reads only the captured context
          -- (bufnr, cursor_pos, selection), never the live cursor.
          function M.focus(context)
            local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(context.bufnr), ":.")
            if context.is_visual then
              return "this selection from " .. path .. " (lines " .. context.start_line .. "-" .. context.end_line .. "):\n```" .. context.filetype .. "\n" .. context.code .. "\n```"
            end
            local row, col = context.cursor_pos[1], context.cursor_pos[2]
            local line = vim.api.nvim_buf_get_lines(context.bufnr, row - 1, row, false)[1] or ""
            -- the keyword run covering the (0-based) cursor column
            local word = vim.fn.matchstr(line:sub(1, col + 1), "\\k*$") .. vim.fn.matchstr(line:sub(col + 2), "^\\k*")
            local what = word ~= "" and ("the symbol `" .. word .. "`") or "the code"
            local from = math.max(1, row - 8)
            local near = table.concat(vim.api.nvim_buf_get_lines(context.bufnr, from - 1, row + 8, false), "\n")
            return what .. " on line " .. row .. " of " .. path .. ", shown with its surroundings:\n```" .. context.filetype .. "\n" .. near .. "\n```"
          end

          -- Labeled keymaps (global + context buffer) as model context,
          -- deduped by (mode, lhs). keytrans turns the internal lhs back into
          -- readable form (a literal space becomes <Space>). Maps with no
          -- desc are plumbing the user wouldn't ask for by name.
          function M.keymap_corpus(bufnr)
            local out, seen = {}, {}
            for _, mode in ipairs({ "n", "i", "v", "x", "t" }) do
              local maps = vim.api.nvim_get_keymap(mode)
              vim.list_extend(maps, vim.api.nvim_buf_get_keymap(bufnr, mode))
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

          -- Ex commands (global + context buffer). Both APIs return a
          -- name-keyed dict, so merge by key rather than concat.
          function M.command_corpus(bufnr)
            local cmds = vim.api.nvim_get_commands({})
            cmds = vim.tbl_extend("force", cmds, vim.api.nvim_buf_get_commands(bufnr, {}))
            local out = {}
            for name, c in pairs(cmds) do
              local def = c.definition and vim.trim(c.definition) or ""
              out[#out + 1] = def ~= "" and (":" .. name .. " — " .. def) or (":" .. name)
            end
            table.sort(out)
            return table.concat(out, "\n")
          end

          package.loaded["codecompanion_prompts"] = M
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
