import { createPublicClient, http } from 'viem';
import { sepolia } from 'viem/chains';
import { ENV } from '../config/env.js';
import { logger } from '../utils/logger.js';

// Create public client for Sepolia network
export const publicClient = createPublicClient({
  chain: ENV.CHAIN_ID === '11155111' ? sepolia : undefined,
  transport: http(ENV.RPC_URL, {
    retryCount: 3,
    retryDelay: 1000,
  }),
});

// Test client connection
export async function testConnection(): Promise<boolean> {
  try {
    const blockNumber = await publicClient.getBlockNumber();
    logger.info(`✅ Connected to Sepolia network. Latest block: ${blockNumber}`);
    return true;
  } catch (error) {
    logger.error('❌ Failed to connect to Sepolia network:', error);
    return false;
  }
}

export default publicClient; 