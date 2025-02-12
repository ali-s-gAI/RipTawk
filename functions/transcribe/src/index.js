// index.js
import OpenAI from 'openai';

export default async function(context) {
  try {
    context.log('🎯 Function triggered');
    
    // Log the raw payload
    context.log('📦 Raw payload:', JSON.stringify(context.req.body));
    
    // Validate payload
    if (!context.req.body) {
      context.error('❌ No payload received');
      return { error: 'No payload received' };
    }
    
    // Get base64 audio from the request
    const { audio, format } = context.req.body;
    
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
      return { error: 'Invalid base64 data' };
    }
    
    // Convert base64 to buffer
    const fileBuffer = Buffer.from(audio, 'base64');
    context.log('📦 Converted buffer size:', fileBuffer.length);
    
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
    return { error: error.toString() };
  }
}
