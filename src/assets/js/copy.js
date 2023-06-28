document.addEventListener('DOMContentLoaded', () => {
  const opts = {html: 'Copied!', position: 'top'};
  const showTooltip = (tooltip) => {
    tooltip.open();
    setTimeout(() => {
      tooltip.close();
      tooltip.destroy();
    }, 1000);
  }

  const copyReference = (event) => {
    const button = event.target;
    const tooltip = M.Tooltip.init(button, opts);
    showTooltip(tooltip);
    const ref = button.parentElement.querySelector('.reference');
    navigator.clipboard.writeText(ref.innerText);
  }

  document.querySelectorAll('.copy-reference').forEach((btn) => {
    btn.addEventListener('click', copyReference);
  });
});
