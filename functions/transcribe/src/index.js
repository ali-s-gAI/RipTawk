// index.js
import OpenAI from 'openai';

export default async function(req, res) {
  try {
    console.log('🎯 Function triggered');
    
    // Log the raw payload
    console.log('📦 Raw payload:', req.payload);
    
    // Validate payload
    if (!req.payload) {
      console.error('❌ No payload received');
      return res.json({ error: 'No payload received' });
    }
    
    // Get base64 audio from the request
    const { audio, format } = req.payload;
    
    // Validate audio data
    if (!audio) {
      console.error('❌ Missing audio data');
      return res.json({ error: 'Missing audio data' });
    }
    if (!format) {
      console.error('❌ Missing format');
      return res.json({ error: 'Missing format parameter' });
    }
    
    console.log('📦 Received audio data length:', audio.length);
    console.log('📦 Audio format:', format);
    
    // Validate base64
    if (!/^[A-Za-z0-9+/=]+$/.test(audio)) {
      console.error('❌ Invalid base64 data');
      return res.json({ error: 'Invalid base64 data' });
    }
    
    // Convert base64 to buffer
    const fileBuffer = Buffer.from(audio, 'base64');
    console.log('📦 Converted buffer size:', fileBuffer.length);
    
    // Validate buffer size
    if (fileBuffer.length === 0) {
      console.error('❌ Empty audio buffer');
      return res.json({ error: 'Empty audio buffer' });
    }
    
    // Initialize OpenAI client
    const openaiApiKey = process.env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      console.error('❌ Missing OpenAI API key');
      return res.json({ error: 'Missing OPENAI_API_KEY environment variable' });
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
    res.json({ response: transcription.text });
    
  } catch (error) {
    console.error('❌ Function error:', error);
    res.json({ error: error.toString() });
  }
}