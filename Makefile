.PHONY: memo daily

DATE ?= $(shell date +"%Y-%m-%d")

memo:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make memo NAME=topics/example [TITLE='Example Title']"; \
		exit 1; \
	fi
	@name="$(NAME)"; \
	case "$$name" in \
		*.md) filepath="$$name" ;; \
		*) filepath="$$name.md" ;; \
	esac; \
	dir="$$(dirname "$$filepath")"; \
	if [ "$$dir" != "." ]; then mkdir -p "$$dir"; fi; \
	if [ -e "$$filepath" ]; then \
		echo "Error: $$filepath already exists"; \
		exit 1; \
	fi; \
	title="$(TITLE)"; \
	if [ -z "$$title" ]; then \
		base="$$(basename "$$filepath" .md)"; \
		title="$$(echo "$$base" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++){ $$i=toupper(substr($$i,1,1)) substr($$i,2) }}1')"; \
	fi; \
	sed \
		-e "s/{{DATE}}/$(DATE)/g" \
		-e "s/{{TITLE}}/$$title/g" \
		templates/default-memo.md > "$$filepath"; \
	echo "Created $$filepath"

daily:
	@date="$(DATE)"; \
	make memo NAME="daily/$$date" TITLE="$(TITLE)"
