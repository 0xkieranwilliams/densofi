import express from 'express';
import { DomainService } from '../services/domain-service.js';
import { ConnectionManager } from '../services/connection-manager.js';
import { logger } from '../utils/logger.js';

const router = express.Router();

/**
 * Get all domains
 */
router.get('/domains', async (req, res) => {
  try {
    const domains = await DomainService.getAllDomains();
    res.json({
      success: true,
      data: domains,
      count: domains.length
    });
  } catch (error) {
    logger.error('Error fetching domains:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch domains'
    });
  }
});

/**
 * Get domain by name
 */
router.get('/domains/:name', async (req, res) => {
  try {
    const { name } = req.params;
    const domain = await DomainService.getDomainByName(name);
    
    if (!domain) {
      return res.status(404).json({
        success: false,
        error: 'Domain not found'
      });
    }

    res.json({
      success: true,
      data: domain
    });
  } catch (error) {
    logger.error('Error fetching domain:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch domain'
    });
  }
});

/**
 * Check if domain is registered
 */
router.get('/domains/:name/status', async (req, res) => {
  try {
    const { name } = req.params;
    const isRegistered = await DomainService.isDomainRegistered(name);
    
    res.json({
      success: true,
      data: {
        domainName: name,
        isRegistered
      }
    });
  } catch (error) {
    logger.error('Error checking domain status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check domain status'
    });
  }
});

/**
 * Get service connection status
 */
router.get('/status', (req, res) => {
  try {
    const status = ConnectionManager.getStatus();
    res.json({
      success: true,
      data: status
    });
  } catch (error) {
    logger.error('Error getting service status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get service status'
    });
  }
});

/**
 * Trigger manual processing of pending events
 */
router.post('/process-pending', async (req, res) => {
  try {
    await DomainService.processPendingRegistrations();
    await DomainService.processPendingOwnershipUpdates();
    
    res.json({
      success: true,
      message: 'Pending events processed successfully'
    });
  } catch (error) {
    logger.error('Error processing pending events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process pending events'
    });
  }
});

/**
 * Verify domain ownership via DNS
 */ 
router.get('/domains/:name/:walletAddress/verify', async (req, res) => {
  try {
    const { name, walletAddress } = req.params;
    const isVerified = await DomainService.verifyDomainViaDns(name, walletAddress);
    res.json({
      success: true,
      data: {
        domainName: name,
        walletAddress,
        isVerified
      }
    });
  } catch (error) {
    logger.error('Error verifying domain:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to verify domain'
    });
  }
});

export { router as domainRoutes }; 