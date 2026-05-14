const isSocketReset = (error) => {
  return error && typeof error === 'object' && error.code === 'ECONNRESET';
};

process.on('uncaughtException', (error) => {
  if (isSocketReset(error)) {
    console.warn('[dev-process] ignored socket reset:', error.message);
    return;
  }

  throw error;
});

process.on('unhandledRejection', (reason) => {
  if (isSocketReset(reason)) {
    console.warn('[dev-process] ignored socket reset:', reason.message);
  }
});
