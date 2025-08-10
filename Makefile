main = thesis_charisfil
BUILD_DIR = build

TEX_FILES := $(shell find . -name "*.tex" -not -path "./$(BUILD_DIR)/*")
BIB_FILES := $(shell find . -name "*.bib" -not -path "./$(BUILD_DIR)/*")

GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
RED = \033[0;31m
NC = \033[0m
BOLD = \033[1m

define progress_bar
	@current=$(1); total=$(2); message="$(3)"; \
	printf "$(BLUE)["; i=1; while [ $$i -le $$current ]; do printf "█"; i=$$((i+1)); done; \
	i=$$((current+1)); while [ $$i -le $$total ]; do printf "░"; i=$$((i+1)); done; \
	printf "]$(NC) ($$current/$$total) $$message\n"
endef

define show_spinner
	@printf "$(BLUE)⠋$(NC) $(1)"; sleep 0.5; printf "\r$(GREEN)✓$(NC) $(2)\n"
endef

.PHONY: all clean distclean view watch help bib-only force-rebuild check-warnings check-bib cleanup

all: $(main).pdf

$(main).pdf: $(TEX_FILES) $(BIB_FILES) | $(BUILD_DIR)
	@echo "$(BOLD)Building PDF: $(main).pdf$(NC)"
	@echo "$(YELLOW)═══════════════════════════════════════$(NC)"
	
	$(call progress_bar,1,5,Step 1/5: Initial LaTeX compilation...)
	$(call show_spinner,Generating auxiliary files...,First LaTeX pass completed)
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" > $(BUILD_DIR)/build.log 2>&1 || true
	
	$(call progress_bar,2,5,Step 2/5: Processing bibliography...)
	if [ -f "$(BUILD_DIR)/$(main).aux" ] && grep -q "\\citation\|\\bibdata\|\\bibstyle" "$(BUILD_DIR)/$(main).aux"; then \
		ln -sf ../bibliography $(BUILD_DIR)/bibliography; \
		cd $(BUILD_DIR) && bibtex "$(main)" >> build.log 2>&1; \
		$(call show_spinner,Building bibliography...,Bibliography processed); \
	else \
		echo "$(YELLOW)ℹ$(NC) No bibliography needed"; \
	fi
	
	$(call progress_bar,3,5,Step 3/5: Resolving references...)
	$(call show_spinner,Building cross-references...,References resolved)
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" >> $(BUILD_DIR)/build.log 2>&1 || true
	
	$(call progress_bar,4,5,Step 4/5: Finalizing document structure...)
	$(call show_spinner,Building final structure...,Document structure finalized)
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" >> $(BUILD_DIR)/build.log 2>&1 || true
	
	$(call progress_bar,5,5,Step 5/5: Final verification...)
	if [ -f "$(BUILD_DIR)/$(main).pdf" ]; then \
		cp "$(BUILD_DIR)/$(main).pdf" . && \
		echo "$(GREEN)✅ PDF built successfully: $(BOLD)$(main).pdf$(NC)"; \
		echo "$(GREEN)📄 File size: $(du -h $(main).pdf | cut -f1)$(NC)"; \
		echo "$(BLUE)📊 Build log: $(BUILD_DIR)/build.log$(NC)"; \
	else \
		echo "$(RED)❌ PDF build failed$(NC)"; \
		echo "$(YELLOW)🔍 Last 10 lines of build log:$(NC)"; \
		tail -10 "$(BUILD_DIR)/build.log" 2>/dev/null || echo "No log file found"; \
		exit 1; \
	fi

quick: $(TEX_FILES) $(BIB_FILES) | $(BUILD_DIR)
	@echo "$(BOLD)Quick Build Mode$(NC)"
	@echo "$(BLUE)▶$(NC) Starting optimized compilation..."
	@printf "$(BLUE)⠋$(NC) Compiling document in quick mode..."
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" > $(BUILD_DIR)/quick.log 2>&1 || true
	if [ -f "$(BUILD_DIR)/$(main).aux" ] && grep -q "\\citation\|\\bibdata\|\\bibstyle" "$(BUILD_DIR)/$(main).aux"; then \
		cd $(BUILD_DIR) && bibtex "$(main)" >> quick.log 2>&1 || true; \
		xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" >> quick.log 2>&1 || true; \
	fi
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" >> $(BUILD_DIR)/quick.log 2>&1 || true
	@printf "\r$(GREEN)✓$(NC) Quick build completed\n"
	if [ -f "$(BUILD_DIR)/$(main).pdf" ]; then \
		cp "$(BUILD_DIR)/$(main).pdf" . && \
		echo "$(GREEN)✅ Quick build successful: $(BOLD)$(main).pdf$(NC)"; \
	else \
		echo "$(RED)❌ Quick build failed$(NC)"; \
		tail -10 "$(BUILD_DIR)/quick.log" 2>/dev/null || echo "No log file found"; \
		exit 1; \
	fi

force-rebuild: 
	@echo "$(BOLD)Force Rebuild$(NC)"
	@echo "$(BLUE)🧹$(NC) Cleaning previous build..."
	$(MAKE) clean > /dev/null 2>&1
	@echo "$(GREEN)✓$(NC) Clean completed"
	$(MAKE) all

debug-build: | $(BUILD_DIR)
	@echo "$(BOLD)Debug Build Mode$(NC)"
	@echo "$(YELLOW)═══════════════════════════════════════$(NC)"
	
	@echo "$(BLUE)Step 1/4:$(NC) First LaTeX pass (generating aux files)"
	@printf "$(BLUE)⠋$(NC) Running first LaTeX pass..."
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" | tee $(BUILD_DIR)/debug.log
	@printf "\r$(GREEN)✓$(NC) Step 1 completed\n"
	
	@echo "$(BLUE)Step 2/4:$(NC) Processing bibliography"
	if [ -f "$(BUILD_DIR)/$(main).aux" ] && grep -q "\\citation\|\\bibdata\|\\bibstyle" "$(BUILD_DIR)/$(main).aux"; then \
		printf "$(BLUE)⠋$(NC) Processing bibliography..."; \
		cd $(BUILD_DIR) && bibtex "$(main)" | tee -a debug.log; \
		printf "\r$(GREEN)✓$(NC) Step 2 completed\n"; \
	else \
		echo "$(YELLOW)ℹ$(NC) No bibliography to process"; \
	fi
	
	@echo "$(BLUE)Step 3/4:$(NC) Second LaTeX pass (resolving references)"
	@printf "$(BLUE)⠋$(NC) Running second LaTeX pass..."
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" | tee -a $(BUILD_DIR)/debug.log
	@printf "\r$(GREEN)✓$(NC) Step 3 completed\n"
	
	@echo "$(BLUE)Step 4/4:$(NC) Final LaTeX pass (completing document)"
	@printf "$(BLUE)⠋$(NC) Running final LaTeX pass..."
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" | tee -a $(BUILD_DIR)/debug.log
	@printf "\r$(GREEN)✓$(NC) Step 4 completed\n"
	
	if [ -f "$(BUILD_DIR)/$(main).pdf" ]; then \
		cp "$(BUILD_DIR)/$(main).pdf" . && \
		echo "$(GREEN)🎉 Debug build completed successfully!$(NC)"; \
		echo "$(BLUE)📋 Full debug log: $(BUILD_DIR)/debug.log$(NC)"; \
	else \
		echo "$(RED)❌ Debug build failed$(NC)"; \
		echo "$(YELLOW)🔍 Check debug log: $(BUILD_DIR)/debug.log$(NC)"; \
		exit 1; \
	fi

errors-only: $(TEX_FILES) $(BIB_FILES) | $(BUILD_DIR)
	@echo "$(BOLD)Error-Only Build$(NC)"
	$(call show_spinner,Building and filtering errors...,Build completed)
	latexmk -f -xelatex -bibtex -interaction=nonstopmode -file-line-error -outdir=$(BUILD_DIR) "$(main).tex" 2>&1 | \
		grep -E "(^LaTeX Error|^!|error:|Error:|FATAL|Fatal|^\*\*\*|Emergency stop|Missing character|Font.*not found|File.*not found)" || true
	if [ -f "$(BUILD_DIR)/$(main).pdf" ]; then \
		mv "$(BUILD_DIR)/$(main).pdf" . && \
		echo "$(GREEN)✅ PDF built successfully (errors filtered)$(NC)"; \
	else \
		echo "$(RED)❌ PDF build failed$(NC)"; \
		tail -20 "$(BUILD_DIR)/$(main).log" 2>/dev/null || echo "Log file not found"; \
		exit 1; \
	fi

quiet: $(TEX_FILES) $(BIB_FILES) | $(BUILD_DIR)
	@echo "$(BLUE)🔇$(NC) Quiet build mode..."
	$(call show_spinner,Building PDF silently...,Quiet build completed)
	latexmk -f -xelatex -bibtex -interaction=batchmode -file-line-error -outdir=$(BUILD_DIR) "$(main).tex" > /dev/null 2>&1
	if [ -f "$(BUILD_DIR)/$(main).pdf" ]; then \
		mv "$(BUILD_DIR)/$(main).pdf" . && \
		echo "$(GREEN)✅ Quiet build successful$(NC)"; \
	else \
		echo "$(RED)❌ Quiet build failed$(NC)"; \
		tail -20 "$(BUILD_DIR)/$(main).log" 2>/dev/null || echo "Log file not found"; \
		exit 1; \
	fi

bib-only: | $(BUILD_DIR)
	@echo "$(BLUE)📚$(NC) Building bibliography only..."
	$(call show_spinner,Processing bibliography...,Bibliography build completed)
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" > /dev/null 2>&1
	if [ -f "$(BUILD_DIR)/$(main).aux" ]; then \
		cd $(BUILD_DIR) && bibtex "$(main)" && \
		echo "$(GREEN)✅ Bibliography built successfully$(NC)"; \
	else \
		echo "$(RED)❌ No .aux file found - LaTeX compilation failed$(NC)"; \
		exit 1; \
	fi

$(BUILD_DIR):
	@echo "$(BLUE)📁$(NC) Creating build directory: $(BUILD_DIR)"
	@mkdir -p $(BUILD_DIR)

clean:
	@echo "$(YELLOW)🧹$(NC) Cleaning build directory and auxiliary files..."
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR) && \
		echo "$(GREEN)✅$(NC) Cleaned build directory"; \
	else \
		echo "$(YELLOW)ℹ$(NC) Build directory already clean"; \
	fi
	@rm -f *.aux *.log *.bbl *.blg *.toc *.out *.lof *.lot 2>/dev/null || true

distclean: clean
	@echo "$(YELLOW)🗑$(NC) Removing PDF files..."
	@if [ -f "$(main).pdf" ]; then \
		rm -f "$(main).pdf" && \
		echo "$(GREEN)✅$(NC) Removed PDF file"; \
	else \
		echo "$(YELLOW)ℹ$(NC) No PDF file to remove"; \
	fi

view: $(main).pdf
	@echo "$(BLUE)👁$(NC) Opening PDF..."
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open $(main).pdf && echo "$(GREEN)✅$(NC) PDF opened with default viewer"; \
	elif command -v open >/dev/null 2>&1; then \
		open $(main).pdf && echo "$(GREEN)✅$(NC) PDF opened with default viewer"; \
	elif command -v start >/dev/null 2>&1; then \
		start $(main).pdf && echo "$(GREEN)✅$(NC) PDF opened with default viewer"; \
	else \
		echo "$(YELLOW)📄$(NC) Please open $(main).pdf manually."; \
	fi

watch: | $(BUILD_DIR)
	@echo "$(BLUE)👀$(NC) Starting continuous watch mode..."
	@echo "$(YELLOW)Press Ctrl+C to stop$(NC)"
	latexmk -xelatex -bibtex -interaction=nonstopmode -file-line-error -pvc -outdir=$(BUILD_DIR) "$(main).tex"

check-warnings: | $(BUILD_DIR)
	@echo "$(BOLD)🔍 LaTeX Warning Check$(NC)"
	@echo "$(YELLOW)═══════════════════════════════════════$(NC)"
	@echo "$(BLUE)Running diagnostic compilation...$(NC)"
	xelatex -interaction=nonstopmode -file-line-error -output-directory=$(BUILD_DIR) "$(main).tex" > $(BUILD_DIR)/warning_check.log 2>&1 || true
	@echo ""
	@echo "$(BOLD)📋 Diagnostic Results:$(NC)"
	@echo "$(BLUE)Missing files:$(NC)"
	@grep -i "no file\|file.*not found\|missing" $(BUILD_DIR)/warning_check.log || echo "  $(GREEN)✓$(NC) No missing files detected"
	@echo ""
	@echo "$(BLUE)Font warnings:$(NC)"
	@grep -i "font.*warning\|opentype feature.*not available" $(BUILD_DIR)/warning_check.log || echo "  $(GREEN)✓$(NC) No font warnings detected"
	@echo ""
	@echo "$(BLUE)Bibliography status:$(NC)"
	@if [ -f "$(BUILD_DIR)/$(main).aux" ]; then \
		if grep -q "\\citation\|\\bibdata\|\\bibstyle" "$(BUILD_DIR)/$(main).aux"; then \
			echo "  $(GREEN)✓$(NC) Bibliography references found"; \
		else \
			echo "  $(YELLOW)ℹ$(NC) No bibliography references in document"; \
		fi; \
	else \
		echo "  $(RED)❌$(NC) No .aux file generated"; \
	fi
	@echo ""
	@echo "$(BLUE)Package warnings:$(NC)"
	@grep -i "package.*warning" $(BUILD_DIR)/warning_check.log || echo "  $(GREEN)✓$(NC) No package warnings detected"

check-bib: | $(BUILD_DIR)
	@echo "$(BOLD)Bibliography Check$(NC)"
	@echo "$(YELLOW)═══════════════════════════════════════$(NC)"
	@echo "$(BLUE)Checking bibliography files...$(NC)"
	@for file in $(BIB_FILES); do \
		echo "$(YELLOW)Checking $$file:$(NC)"; \
		if [ -f "$$file" ]; then \
			echo "  $(GREEN)✓$(NC) File exists"; \
		else \
			echo "  $(RED)❌$(NC) File not found"; \
		fi; \
	done
help:
	@echo "$(BOLD)Help$(NC)"
	@echo "$(YELLOW)═══════════════════════════════════════$(NC)"
	@echo "$(BLUE)Available targets:$(NC)"
	@echo "  all        Build the entire project"
	@echo "  clean      Remove build artifacts"
	@echo "  distclean  Remove all generated files"
	@echo "  view       Open the generated PDF"
	@echo "  watch      Start watching for changes"
	@echo "  check-warnings  Check for LaTeX warnings"
	@echo "  check-bib  Check bibliography files"
	@echo "  help       Show this help message"
cleanup:
	@rm -f /tmp/latex_building_$(main)
