// index.js
import fetch from 'node-fetch';
import FormData from 'form-data';

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
    
    // Prepare the form data
    const form = new FormData();
    form.append('file', fileBuffer, {
      filename: `audio.${format}`,
      contentType: `audio/${format}`
    });
    form.append('model', 'whisper-1');
    
    // Log OpenAI API key presence (not the actual key)
    const openaiApiKey = process.env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      console.error('❌ Missing OpenAI API key');
      res.json({ error: 'Missing OPENAI_API_KEY environment variable' });
      return;
    }
    console.log('✅ OpenAI API key found');
    
    console.log('🎙 Calling Whisper API...');
    const whisperResponse = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: form
    });
    
    console.log('📡 Whisper API response status:', whisperResponse.status);
    
    if (!whisperResponse.ok) {
      const errText = await whisperResponse.text();
      console.error('❌ Whisper API error:', errText);
      res.json({ error: 'Whisper API error', details: errText });
      return;
    }
    
    const result = await whisperResponse.json();
    console.log('✅ Received transcript length:', result.text.length);
    
    // Return the transcript text
    res.json({ response: result.text });
  } catch (error) {
    console.error('❌ Function error:', error);
    res.json({ error: error.toString() });
  }
};