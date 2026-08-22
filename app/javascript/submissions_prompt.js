document.addEventListener('DOMContentLoaded', () => {
  const promptBtn = document.getElementById('get-prompt-btn');
  if (!promptBtn) return;

  const spinner = document.getElementById('prompt-spinner');

  promptBtn.addEventListener('click', async (e) => {
    e.preventDefault();
    promptBtn.disabled = true;
    spinner?.classList.remove('hidden');

    try {
      const response = await fetch('/writing_prompt.json');
      const data = await response.json();
      const titleField = document.querySelector('input[name="submission[title]"]');

      if (data.prompt && titleField) {
        titleField.value = data.prompt;
      }
    } finally {
      promptBtn.disabled = false;
      spinner?.classList.add('hidden');
    }
  });
});
