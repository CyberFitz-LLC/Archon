/**
 * Unified clipboard utility with comprehensive error handling, 
 * security context checks, and fallback methods
 */

export interface ClipboardResult {
  success: boolean;
  method: 'modern' | 'fallback' | 'failed';
  error?: string;
}

/**
 * Copy text to clipboard with robust error handling and fallback methods
 * @param text - The text to copy to clipboard
 * @param showDebugLogs - Whether to show debug logs (default: false)
 * @returns Promise<ClipboardResult> - Result object with success status and method used
 */
export async function copyToClipboard(text: string, showDebugLogs = false): Promise<ClipboardResult> {
  if (!text) {
    return { success: false, method: 'failed', error: 'No text provided' };
  }

  if (showDebugLogs) {
    console.log('[Clipboard] Attempting to copy:', text.substring(0, 50) + (text.length > 50 ? '...' : ''));
    console.log('[Clipboard] Environment:', {
      hasClipboardAPI: !!navigator.clipboard,
      isSecureContext: window.isSecureContext,
      protocol: window.location.protocol,
      hasFocus: document.hasFocus(),
      visibilityState: document.visibilityState
    });
  }

  // Method 1: Modern Clipboard API (preferred)
  if (navigator.clipboard && window.isSecureContext) {
    try {
      await navigator.clipboard.writeText(text);
      if (showDebugLogs) {
        console.log('[Clipboard] ✅ Success with modern API');
      }
      return { success: true, method: 'modern' };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      if (showDebugLogs) {
        console.warn('[Clipboard] ❌ Modern API failed:', errorMessage);
        console.log('[Clipboard] Falling back to legacy method...');
      }
      // Don't return here, continue to fallback method
    }
  } else {
    if (showDebugLogs) {
      if (!navigator.clipboard) {
        console.log('[Clipboard] ⚠️ Clipboard API not available');
      }
      if (!window.isSecureContext) {
        console.log('[Clipboard] ⚠️ Not in secure context (HTTPS required for Clipboard API)');
      }
      console.log('[Clipboard] Using fallback method...');
    }
  }

  // Method 2: Fallback using document.execCommand (works in most browsers)
  try {
    // Ensure document has focus for execCommand to work
    if (!document.hasFocus()) {
      window.focus();
    }

    const textArea = document.createElement('textarea');
    textArea.value = text;
    
    // Position off-screen to avoid visual flash
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    textArea.style.width = '1px';
    textArea.style.height = '1px';
    textArea.style.opacity = '0';
    textArea.style.border = 'none';
    textArea.style.outline = 'none';
    textArea.style.boxShadow = 'none';
    textArea.style.background = 'transparent';
    
    // Add to DOM
    document.body.appendChild(textArea);
    
    // Focus and select
    textArea.focus();
    textArea.select();
    textArea.setSelectionRange(0, text.length);
    
    // Attempt copy
    const successful = document.execCommand('copy');
    
    // Clean up
    document.body.removeChild(textArea);
    
    if (successful) {
      if (showDebugLogs) {
        console.log('[Clipboard] ✅ Success with fallback method');
      }
      return { success: true, method: 'fallback' };
    } else {
      if (showDebugLogs) {
        console.warn('[Clipboard] ❌ Fallback method failed: execCommand returned false');
      }
      return { 
        success: false, 
        method: 'failed', 
        error: 'execCommand copy returned false' 
      };
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (showDebugLogs) {
      console.error('[Clipboard] ❌ Fallback method error:', errorMessage);
    }
    return { 
      success: false, 
      method: 'failed', 
      error: `Fallback method failed: ${errorMessage}` 
    };
  }
}

/**
 * Read text from clipboard with error handling
 * @param showDebugLogs - Whether to show debug logs (default: false)
 * @returns Promise<string | null> - The clipboard text or null if failed
 */
export async function readFromClipboard(showDebugLogs = false): Promise<string | null> {
  if (!navigator.clipboard) {
    if (showDebugLogs) {
      console.log('[Clipboard] Read not available: no clipboard API');
    }
    return null;
  }

  if (!window.isSecureContext) {
    if (showDebugLogs) {
      console.log('[Clipboard] Read not available: not in secure context');
    }
    return null;
  }

  try {
    const text = await navigator.clipboard.readText();
    if (showDebugLogs) {
      console.log('[Clipboard] ✅ Read success:', text.substring(0, 50) + (text.length > 50 ? '...' : ''));
    }
    return text;
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (showDebugLogs) {
      console.warn('[Clipboard] ❌ Read failed:', errorMessage);
    }
    return null;
  }
}

/**
 * Check if clipboard functionality is available
 * @returns boolean - True if some form of clipboard copy is available
 */
export function isClipboardAvailable(): boolean {
  // Modern API available and in secure context
  if (navigator.clipboard && window.isSecureContext) {
    return true;
  }
  
  // Fallback method available
  if (document.execCommand) {
    return true;
  }
  
  return false;
}

/**
 * Get clipboard availability details for debugging
 * @returns object with detailed clipboard status
 */
export function getClipboardStatus() {
  return {
    hasClipboardAPI: !!navigator.clipboard,
    isSecureContext: window.isSecureContext,
    hasExecCommand: !!document.execCommand,
    protocol: window.location.protocol,
    hasFocus: document.hasFocus(),
    visibilityState: document.visibilityState,
    available: isClipboardAvailable()
  };
}