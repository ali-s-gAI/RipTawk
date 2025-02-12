// index.js
import OpenAI from 'openai';

export default async function(context) {
  try {
    console.log('🎯 Function triggered');
    
    // Log the raw payload
    console.log('📦 Raw payload:', context.req.body);
    
    // Validate payload
    if (!context.req.body) {
      console.error('❌ No payload received');
      return { error: 'No payload received' };
    }
    
    // Get base64 audio from the request
    const { audio, format } = context.req.body;
    
    // Validate audio data
    if (!audio) {
      console.error('❌ Missing audio data');
      return { error: 'Missing audio data' };
    }
    if (!format) {
      console.error('❌ Missing format');
      return { error: 'Missing format parameter' };
    }
    
    console.log('📦 Received audio data length:', audio.length);
    console.log('📦 Audio format:', format);
    
    // Validate base64
    if (!/^[A-Za-z0-9+/=]+$/.test(audio)) {
      console.error('❌ Invalid base64 data');
      return { error: 'Invalid base64 data' };
    }
    
    // Convert base64 to buffer
    const fileBuffer = Buffer.from(audio, 'base64');
    console.log('📦 Converted buffer size:', fileBuffer.length);
    
    // Validate buffer size
    if (fileBuffer.length === 0) {
      console.error('❌ Empty audio buffer');
      return { error: 'Empty audio buffer' };
    }
    
    // Initialize OpenAI client
    const openaiApiKey = context.req.variables['OPENAI_API_KEY'];
    if (!openaiApiKey) {
      console.error('❌ Missing OpenAI API key');
      return { error: 'Missing OPENAI_API_KEY environment variable' };
    }
    
    const openai = new OpenAI({
      apiKey: openaiApiKey
    });
    
    console.log('✅ OpenAI client initialized');
    console.log('🎙 Calling Whisper API...');
    
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
    
    console.log('✅ Received transcript length:', transcription.text.length);
    
    // Return the transcript text
    return { response: transcription.text };
    
  } catch (error) {
    console.error('❌ Function error:', error);
    return { error: error.toString() };
  }
}
