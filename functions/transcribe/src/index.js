// index.js
import OpenAI from 'openai';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { Client, Databases } from 'appwrite';

async function generateDescription(openai, transcript) {
  const response = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: "You are a financial content expert. Generate a concise description (maximum 48 characters) that captures the main financial insight or prediction from the given transcript."
      },
      {
        role: "user",
        content: transcript
      }
    ],
    max_tokens: 50,
    temperature: 0.3
  });
  
  return response.choices[0].message.content.trim();
}

async function extractTickers(openai, transcript) {
  const response = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: `You are a financial expert that extracts and converts mentions of:
        1. Companies to their stock tickers (e.g., "Microsoft" -> "MSFT")
        2. Cryptocurrencies to their symbols (e.g., "Bitcoin" -> "BTC")
        3. Commodities as is (e.g., "Gold" stays "Gold")
        
        Return ONLY a JSON array of strings, with NO additional text.
        If nothing is found, return an empty array.
        Format: ["TICKER1", "TICKER2"]
        
        Example: For "Microsoft and Apple are doing well", return: ["MSFT", "AAPL"]`
      },
      {
        role: "user",
        content: transcript
      }
    ],
    temperature: 0
  });
  
  try {
    const content = response.choices[0].message.content.trim();
    // Extract array portion using regex
    const match = content.match(/\[.*\]/);
    if (match) {
      return JSON.parse(match[0]);
    }
    console.log("Could not find array in response:", content);
    return [];
  } catch (error) {
    console.error('Failed to parse tickers response:', error);
    console.log('Raw response:', response.choices[0].message.content);
    return [];
  }
}

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
    
    // Check for documentId early
    if (!payload.documentId) {
      console.error('❌ Missing documentId in payload');
      return { error: 'Missing documentId parameter' };
    }
    console.log('📄 Processing document:', payload.documentId);
    
    // Destructure audio and format from the payload
    const { audio, format, documentId } = payload;
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
    console.log('📝 Transcript content:', transcription.text);
    console.log('🔍 Full transcription response:', JSON.stringify(transcription, null, 2));
    
    // Generate description and extract tickers using GPT-4
    console.log('🤖 Generating description using GPT-4...');
    const description = await generateDescription(openai, transcription.text);
    console.log('📝 Generated description:', description);
    
    console.log('🔍 Extracting tickers using GPT-4...');
    const tags = await extractTickers(openai, transcription.text);
    console.log('🏷 Extracted tickers:', tags);

    // Initialize Appwrite client
    console.log('🔄 Initializing Appwrite client...');
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_FUNCTION_ENDPOINT)
      .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
      .setKey(process.env.APPWRITE_FUNCTION_API_KEY);

    const databases = new Databases(client);

    // Update the document in Appwrite
    try {
      const databaseId = "67a2ea9400210dd0d73b";  // main
      const collectionId = "67a2eaa90034a69780ef";  // videos

      console.log('📝 Updating document:', {
        databaseId,
        collectionId,
        documentId,
        data: {
          description,
          tags,
          transcript: transcription.text,
          isTranscribed: true
        }
      });

      await databases.updateDocument(
        databaseId,
        collectionId,
        documentId,
        {
          description: description,
          tags: tags,
          transcript: transcription.text,
          isTranscribed: true
        }
      );
      
      console.log('✅ Updated Appwrite document with description and tags');
    } catch (updateError) {
      console.error('❌ Failed to update Appwrite document:', updateError);
      console.error('Error details:', {
        message: updateError.message,
        stack: updateError.stack,
        context: updateError.context
      });
      throw updateError;
    }

    await fs.promises.unlink(tempPath).catch(err => console.error('Error deleting temporary file:', err));
    
    // Return the processed data
    return {
      response: transcription.text,
      description: description,
      tags: tags
    };
    
  } catch (error) {
    console.error('❌ Function error:', error);
    return { error: error.toString() };
  }
}
