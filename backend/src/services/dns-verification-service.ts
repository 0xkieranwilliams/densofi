import dns from 'dns';
import { normalize } from 'viem/ens'
import { logger } from '../utils/logger.js';

export class DnsVerificationService {
  /**
   * Verifies domain ownership by checking for a specific TXT record.
   * The TXT record should contain the wallet address.
   *
   * @param domainName - The domain name to verify (e.g., "example.com").
   * @param walletAddress - The wallet address expected in the TXT record.
   * @returns True if a valid TXT record is found, false otherwise.
   */
  static async verifyDomainOwnership(domainName: string, walletAddress: string): Promise<boolean> {
    logger.info(`Attempting to verify domain ownership for ${domainName} with wallet ${walletAddress}`);
    let ensTxtRecordHostname: string = ''; 
    try {
      // Construct the full hostname for the _ens TXT record
      ensTxtRecordHostname = `_densofi.${domainName}`;
      const records = await dns.promises.resolveTxt(ensTxtRecordHostname);
      
      // TXT records can be an array of arrays of strings (e.g., [['v=spf1...'], ['google-site-verification=...']])
      // Or sometimes, a single TXT record string is split into multiple chunks within one of the inner arrays.
      // We need to check if any of the resolved TXT records (or their concatenated chunks) contain the wallet address.
      for (const record of records) {
        const recordText = Array.isArray(record) ? record.join('') : record;
        // The user's TXT record shows 'a=0x...', so we should specifically look for that format.
        if (recordText.includes(`a=${walletAddress}`)) {
          logger.info(`Successfully verified ownership of ${domainName} for wallet ${walletAddress}. Found TXT record: "${recordText}"`);
          return true;
        }
      }

      logger.warn(`No matching TXT record found for ${domainName} containing wallet address ${walletAddress}. Records found: ${JSON.stringify(records)}`);
      return false;
    } catch (error: any) {
      // Common errors: ENOTFOUND (domain does not exist), ENODATA (no TXT records)
      if (error.code === 'ENOTFOUND' || error.code === 'ENODATA') {
        logger.warn(`DNS query failed for ${ensTxtRecordHostname}: ${error.code} - ${error.message}`);
      } else {
        logger.error(`Error verifying domain ownership for ${domainName}:`, error);
      }
      return false;
    }
  }
} 