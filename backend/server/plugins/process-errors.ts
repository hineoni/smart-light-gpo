export default defineNitroPlugin(() => {
  const isSocketReset = (error: unknown) => {
    return error instanceof Error && (error as NodeJS.ErrnoException).code === 'ECONNRESET';
  };

  process.on('uncaughtException', (error) => {
    if (isSocketReset(error)) {
      console.warn('[process] ignored socket reset:', error.message);
      return;
    }
    throw error;
  });

  process.on('unhandledRejection', (reason) => {
    if (isSocketReset(reason)) {
      console.warn('[process] ignored socket reset:', (reason as Error).message);
    }
  });
});
