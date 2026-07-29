document.addEventListener('DOMContentLoaded', () => {
  const contentField = document.querySelector('textarea[name="submission[content]"]');
  const timerDisplay = document.getElementById('writing-timer');
  if (!contentField || !timerDisplay) return;

  const IDLE_TIMEOUT_MS = 3000;
  let elapsedSeconds = 0;
  let tickInterval = null;
  let idleTimeout = null;

  const formatTime = (totalSeconds) => {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
  };

  const updateDisplay = () => {
    timerDisplay.textContent = formatTime(elapsedSeconds);
  };

  const stopTicking = () => {
    clearInterval(tickInterval);
    tickInterval = null;
  };

  const startTicking = () => {
    if (tickInterval) return;
    tickInterval = setInterval(() => {
      elapsedSeconds += 1;
      updateDisplay();
    }, 1000);
  };

  contentField.addEventListener('input', () => {
    startTicking();
    clearTimeout(idleTimeout);
    idleTimeout = setTimeout(stopTicking, IDLE_TIMEOUT_MS);
  });

  updateDisplay();
});
