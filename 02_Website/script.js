function selectStage(button) {
  const panel = document.querySelector("[data-stage-panel]");
  const progress = document.querySelector("[data-stage-progress]");
  if (!panel || !progress) return;

  panel.querySelector(".stage-index").textContent = button.dataset.step || "01";
  panel.querySelector("h3").textContent = button.dataset.title || "";
  panel.querySelector("p").textContent = button.dataset.body || "";
  progress.style.width = button.dataset.progress || "25%";

  document.querySelectorAll(".state-step").forEach((step) => {
    step.classList.toggle("is-active", step === button);
  });
}

function setStoryState(index) {
  const buttons = Array.from(document.querySelectorAll(".state-step"));
  const button = buttons[Math.min(buttons.length - 1, Math.max(0, index))];
  if (button) selectStage(button);
}

function wireStateButtons() {
  document.querySelectorAll(".state-step").forEach((button, index) => {
    button.addEventListener("click", () => setStoryState(index));
  });
}

function wireScrollStory() {
  const story = document.querySelector(".scroll-story");
  if (!story) return;

  const onScroll = () => {
    const rect = story.getBoundingClientRect();
    const distance = Math.max(1, rect.height - window.innerHeight);
    const ratio = Math.min(1, Math.max(0, -rect.top / distance));
    const count = document.querySelectorAll(".state-step").length || 1;
    setStoryState(Math.min(count - 1, Math.floor(ratio * count)));
  };

  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
}

function wireCopyButton() {
  const button = document.querySelector("[data-copy-command]");
  const command = document.querySelector("[data-command]");
  if (!button || !command) return;

  const defaultLabel = button.dataset.copyLabel || button.textContent.trim();
  const copiedLabel = button.dataset.copiedLabel || "Copied";

  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(command.textContent.trim());
      button.textContent = copiedLabel;
      window.setTimeout(() => {
        button.textContent = defaultLabel;
      }, 1400);
    } catch {
      button.textContent = defaultLabel;
    }
  });
}

wireStateButtons();
wireScrollStory();
wireCopyButton();
