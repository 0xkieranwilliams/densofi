import { ENV } from '../config/env.js';
import { logger } from './logger.js';

export function validateConfiguration(): void {
  const errors: string[] = [];
  const warnings: string[] = [];

  // Check MongoDB configuration
  if (!ENV.MONGO_URL && !(ENV.MONGOHOST && ENV.MONGOPORT && ENV.MONGOUSER && ENV.MONGOPASSWORD)) {
    errors.push('MongoDB configuration is missing');
    logger.error('❌ MongoDB Configuration Error:');
    logger.error('   Please set either:');
    logger.error('   Option 1: MONGO_URL=mongodb://username:password@host:port/database');
    logger.error('   Option 2: Individual variables:');
    logger.error('     MONGOHOST=localhost');
    logger.error('     MONGOPORT=27017');
    logger.error('     MONGOUSER=your_username');
    logger.error('     MONGOPASSWORD=your_password');
    logger.error('   Also required: MONGO_DB=densofi_domains');
  }

  // Check database name
  if (!ENV.MONGO_DB) {
    errors.push('MONGO_DB is required');
    logger.error('❌ Missing MONGO_DB environment variable');
  }

  // Check RPC URL
  if (!ENV.RPC_URL) {
    errors.push('RPC_URL is required');
    logger.error('❌ Missing RPC_URL environment variable');
    logger.error('   Example: RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY');
  }

  // Warnings for optional but recommended settings
  if (ENV.RPC_URL === 'https://rpc2.sepolia.org') {
    warnings.push('Using default public RPC endpoint - consider using Infura/Alchemy for better reliability');
  }

  if (ENV.POLLING_INTERVAL < 1000) {
    warnings.push('POLLING_INTERVAL is very low - this might cause rate limiting');
  }

  // Log warnings
  warnings.forEach(warning => {
    logger.warn(`⚠️  ${warning}`);
  });

  // Throw error if critical config is missing
  if (errors.length > 0) {
    logger.error('❌ Configuration validation failed. Please fix the above errors.');
    throw new Error(`Configuration validation failed: ${errors.join(', ')}`);
  }

  logger.info('✅ Configuration validation passed');
}

export function logConfiguration(): void {
  logger.info('📋 Configuration Summary:');
  logger.info(`   Database: ${ENV.MONGO_DB}`);
  logger.info(`   RPC URL: ${ENV.RPC_URL}`);
  logger.info(`   Contract: ${ENV.DOMAIN_REGISTRATION_CONTRACT}`);
  logger.info(`   Polling Interval: ${ENV.POLLING_INTERVAL}ms`);
  logger.info(`   Port: ${ENV.PORT}`);
} 