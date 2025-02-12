// index.js

const fetch = require('node-fetch');
const FormData = require('form-data');

module.exports = async function (req, res) {
  try {
    // Retrieve fileUrl from the function payload
    const fileUrl = req.payload.fileUrl;
    if (!fileUrl) {
      res.json({ error: 'Missing fileUrl parameter' });
      return;
    }
    
    // Download the file from the given URL
    const fileResponse = await fetch(fileUrl);
    if (!fileResponse.ok) {
      res.json({ error: 'Failed to download file', status: fileResponse.status });
      return;
    }
    const fileBuffer = await fileResponse.buffer();

    // Prepare the form data to call OpenAI Whisper API
    const form = new FormData();
    form.append('file', fileBuffer, {
      filename: 'audio.mp3',  // or the appropriate file extension
      contentType: 'audio/mpeg'
    });
    form.append('model', 'whisper-1'); // using the whisper-1 model

    // Retrieve OpenAI API key from environment variable
    const openaiApiKey = process.env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      res.json({ error: 'Missing OPENAI_API_KEY environment variable' });
      return;
    }

    // Call OpenAI Whisper API endpoint
    const whisperResponse = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: form
    });
    
    if (!whisperResponse.ok) {
      const errText = await whisperResponse.text();
      res.json({ error: 'Whisper API error', details: errText });
      return;
    }
    
    const result = await whisperResponse.json();
    // Return the transcript text in a JSON response
    res.json({ transcript: result.text });
  } catch (error) {
    res.json({ error: error.toString() });
  }
};
