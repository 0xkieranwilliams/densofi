import { logger } from './utils/logger.js';
import { ConnectionManager } from './services/connection-manager.js';
import { startServer } from './server.js';
import { validateConfiguration, logConfiguration } from './utils/config-validator.js';

async function main() {
  logger.info('🚀 Starting DensoFi Domain Registration Service...');

  try {
    // Validate configuration first
    validateConfiguration();
    logConfiguration();

    // Initialize all services with retry logic (this will wait for completion)
    await ConnectionManager.initialize();
    logger.info('✅ All services connected and initialized successfully');

    // Start API server only after services are connected
    const server = startServer();

    // Setup graceful shutdown
    setupGracefulShutdown(server);

    logger.info('🎉 Service startup completed successfully');
    logger.info('');
    logger.info('Available endpoints:');
    logger.info('  GET  /health - Health check');
    logger.info('  GET  /api/status - Service connection status');
    logger.info('  GET  /api/domains - Get all registered domains');
    logger.info('  GET  /api/domains/:name - Get specific domain');
    logger.info('  GET  /api/domains/:name/status - Check domain registration status');
    logger.info('  POST /api/process-pending - Manually process pending events');
    
    // Keep the process running
    process.stdin.resume();

  } catch (error) {
    logger.error('❌ Failed to start service:', {
      error: error instanceof Error ? {
        name: error.name,
        message: error.message,
        stack: error.stack
      } : error
    });
    process.exit(1);
  }
}

function setupGracefulShutdown(server?: any) {
  const shutdown = async (signal: string) => {
    logger.info(`Received ${signal}, shutting down gracefully...`);
    
    try {
      // Close API server first
      if (server) {
        await new Promise<void>((resolve) => {
          server.close(() => {
            logger.info('API server closed');
            resolve();
          });
        });
      }

      // Disconnect services
      await ConnectionManager.disconnect();
      logger.info('✅ Graceful shutdown completed');
      process.exit(0);
    } catch (error) {
      logger.error('Error during shutdown:', error);
      process.exit(1);
    }
  };

  // Handle shutdown signals
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  
  // Handle uncaught exceptions
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception:', error);
    shutdown('uncaughtException');
  });

  process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
    shutdown('unhandledRejection');
  });
}

// Start the application
main().catch((error) => {
  logger.error('Failed to start application:', error);
  process.exit(1);
});
