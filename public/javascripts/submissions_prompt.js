document.addEventListener('DOMContentLoaded', () => {
  const promptBtn = document.getElementById('get-prompt-btn');
  if (!promptBtn) return;

  promptBtn.addEventListener('click', async (e) => {
    e.preventDefault();
    const response = await fetch('/writing_prompt.json');
    const data = await response.json();
    const promptDisplay = document.getElementById('prompt-display');
    const titleField = document.querySelector('input[name="submission[title]"]');

    if (data.prompt) {
      promptDisplay.textContent = data.prompt;
      promptDisplay.style.display = 'block';
      if (titleField) {
        titleField.value = data.prompt;
      }
    }
  });
});
