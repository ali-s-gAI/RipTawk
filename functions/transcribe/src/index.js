// index.js
import OpenAI from 'openai';
import fs from 'fs';
import path from 'path';
import os from 'os';

export default async function(context) {
  try {
    console.log('🎯 Function triggered');
    
    // Check and parse the request body if necessary
    let payload = context.req.body;
    if (typeof payload === 'string') {
      console.log('📦 Body is a string, attempting to parse...');
      try {
        payload = JSON.parse(payload);
        console.log('📦 Successfully parsed body');
      } catch (parseError) {
        console.error('❌ Failed to parse request body:', parseError);
        return { error: 'Failed to parse request body' };
      }
    }
    
    console.log('📦 Raw payload:', payload);
    console.log('📦 Payload keys:', Object.keys(payload));
    
    if (!payload) {
      console.error('❌ No payload received');
      return { error: 'No payload received' };
    }
    
    // Destructure audio and format from the payload
    const { audio, format } = payload;
    console.log('📦 Audio value:', audio);
    console.log('📦 Audio type:', typeof audio);
    
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
    
    // Validate base64 string
    if (!/^[A-Za-z0-9+/=]+$/.test(audio)) {
      console.error('❌ Invalid base64 data');
      return { error: 'Invalid base64 data' };
    }
    
    // Convert base64 to buffer
    const fileBuffer = Buffer.from(audio, 'base64');
    console.log('📦 Converted buffer size:', fileBuffer.length);
    
    if (fileBuffer.length === 0) {
      console.error('❌ Empty audio buffer');
      return { error: 'Empty audio buffer' };
    }
    
    // Initialize OpenAI client
    const openaiApiKey = process.env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      console.error('❌ Missing OpenAI API key');
      return { error: 'Missing OPENAI_API_KEY environment variable' };
    }
    
    const openai = new OpenAI({
      apiKey: openaiApiKey
    });
    
    console.log('✅ OpenAI client initialized');
    console.log('🎙 Calling Whisper API...');
    
    // Update the temporary file naming to use the original format from the payload
    const apiFormat = format;
    const tempPath = path.join(os.tmpdir(), `temp-audio-${Date.now()}.${apiFormat}`);
    console.log('📝 Writing temporary file:', tempPath);
    await fs.promises.writeFile(tempPath, fileBuffer);
    console.log('📂 Temporary file written. Creating read stream.');
    const fileStream = fs.createReadStream(tempPath);

    const transcription = await openai.audio.transcriptions.create({
      file: fileStream,
      model: "whisper-1",
      response_format: "json"
    });

    console.log('✅ Received transcript length:', transcription.text.length);
    await fs.promises.unlink(tempPath).catch(err => console.error('Error deleting temporary file:', err));
    
    // Return the transcript text
    return { response: transcription.text };
    
  } catch (error) {
    console.error('❌ Function error:', error);
    return { error: error.toString() };
  }
}
