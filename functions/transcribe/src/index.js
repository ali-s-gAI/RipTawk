// index.js
import OpenAI from 'openai';

export default async function(context) {
  try {
    context.log('🎯 Function triggered');
    
    // Log raw request details
    context.log('📦 Raw request type:', typeof context.req.body);
    context.log('📦 Raw request keys:', Object.keys(context.req.body));
    
    // If body is a string, try to parse it
    let parsedBody = context.req.body;
    if (typeof context.req.body === 'string') {
      context.log('📦 Body is string, attempting to parse...');
      try {
        parsedBody = JSON.parse(context.req.body);
        context.log('📦 Successfully parsed body');
      } catch (e) {
        context.error('❌ Failed to parse body:', e);
        return { error: 'Failed to parse request body' };
      }
    }
    
    // Log parsed payload details
    context.log('📦 Parsed body type:', typeof parsedBody);
    context.log('📦 Parsed body keys:', Object.keys(parsedBody));
    
    // Validate payload
    if (!parsedBody) {
      context.error('❌ No payload received');
      return { error: 'No payload received' };
    }
    
    // Get base64 audio from the request
    const { audio, format } = parsedBody;
    
    // Log detailed payload info
    context.log('📦 Format received:', format);
    context.log('📦 Audio type:', typeof audio);
    context.log('📦 Audio exists:', !!audio);
    if (audio) {
      context.log('📦 Audio length:', audio.length);
      context.log('📦 Audio preview:', audio.substring(0, 100));
    }
    
    // Validate audio data
    if (!audio) {
      context.error('❌ Missing audio data');
      return { error: 'Missing audio data' };
    }
    if (!format) {
      context.error('❌ Missing format');
      return { error: 'Missing format parameter' };
    }
    
    context.log('📦 Received audio data length:', audio.length);
    context.log('📦 Audio format:', format);
    
    // Validate base64
    if (!/^[A-Za-z0-9+/=]+$/.test(audio)) {
      context.error('❌ Invalid base64 data');
      context.error('❌ First 100 chars of audio:', audio.substring(0, 100));
      return { error: 'Invalid base64 data' };
    }
    
    // Convert base64 to buffer
    const fileBuffer = Buffer.from(audio, 'base64');
    context.log('📦 Converted buffer size:', fileBuffer.length);
    context.log('📦 Buffer preview:', fileBuffer.slice(0, 20));
    
    // Validate buffer size
    if (fileBuffer.length === 0) {
      context.error('❌ Empty audio buffer');
      return { error: 'Empty audio buffer' };
    }
    
    // Initialize OpenAI client
    const openaiApiKey = context.req.variables['OPENAI_API_KEY'];
    if (!openaiApiKey) {
      context.error('❌ Missing OpenAI API key');
      return { error: 'Missing OPENAI_API_KEY environment variable' };
    }
    
    const openai = new OpenAI({
      apiKey: openaiApiKey
    });
    
    context.log('✅ OpenAI client initialized');
    context.log('🎙 Calling Whisper API...');
    
    // Create a temporary file object for OpenAI
    const file = {
      buffer: fileBuffer,
      name: `audio.${format}`
    };
    
    // Call Whisper API
    const transcription = await openai.audio.transcriptions.create({
      file: file,
      model: "whisper-1",
    });
    
    context.log('✅ Received transcript length:', transcription.text.length);
    
    // Return the transcript text
    return { response: transcription.text };
    
  } catch (error) {
    context.error('❌ Function error:', error);
    context.error('❌ Error stack:', error.stack);
    return { error: error.toString() };
  }
}
