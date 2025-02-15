import fetch from 'node-fetch';

export default async function(context) {
  try {
    console.log('🎯 Market Data function triggered');
    
    // Parse the request payload
    let payload = context.req.body;
    if (typeof payload === 'string') {
      payload = JSON.parse(payload);
      console.log('📦 Parsed payload:', payload);
    }
    
    const ticker = payload.ticker;
    if (!ticker) {
      console.log('❌ Missing ticker symbol');
      return { error: "Missing ticker symbol" };
    }
    
    // Get API key from environment variables
    const apiKey = process.env.MARKETDATA_API_KEY;
    if (!apiKey) {
      console.log('❌ Missing API key');
      return { error: "Missing MARKETDATA_API_KEY environment variable" };
    }
    
    console.log('🔍 Fetching data for ticker:', ticker);
    
    // Construct API URLs for quote and news
    const quoteUrl = `https://api.marketdata.app/v1/stocks/quotes/${ticker}/`;
    const newsUrl = `https://api.marketdata.app/v1/stocks/news/${ticker}/?countback=5`;
    
    // Fetch quote data
    console.log('📊 Fetching quote data...');
    const quoteResponse = await fetch(quoteUrl, {
      headers: {
        "Authorization": `Bearer ${apiKey}`
      }
    });
    if (!quoteResponse.ok) {
      throw new Error(`Quote API request failed with status ${quoteResponse.status}`);
    }
    const quoteData = await quoteResponse.json();
    console.log('📊 Quote data:', quoteData);
    
    // Extract the "last" price
    const lastPrice = (Array.isArray(quoteData.last) && quoteData.last.length > 0) 
                      ? quoteData.last[0] 
                      : null;
    
    // Fetch news data
    console.log('📰 Fetching news data...');
    const newsResponse = await fetch(newsUrl, {
      headers: {
        "Authorization": `Bearer ${apiKey}`
      }
    });
    if (!newsResponse.ok) {
      throw new Error(`News API request failed with status ${newsResponse.status}`);
    }
    const newsData = await newsResponse.json();
    console.log('📰 News data:', newsData);
    
    // Process news items
    let newsItems = [];
    if (Array.isArray(newsData)) {
      newsItems = newsData.map(item => ({
        headline: item.headline || '',
        content: item.content || item.summary || '',
        source: item.source || '',
        updated: item.updated || Math.floor(Date.now() / 1000)
      }));
    } else if (newsData && newsData.s === "ok" && newsData.headline) {
      newsItems = [{
        headline: newsData.headline,
        content: newsData.content || newsData.summary || '',
        source: newsData.source || '',
        updated: newsData.updated || Math.floor(Date.now() / 1000)
      }];
    }
    
    const response = {
      quote: lastPrice,
      news: newsItems
    };
    
    console.log('✅ Returning response:', JSON.stringify(response, null, 2));
    return response;
    
  } catch (error) {
    console.error("❌ Market Data function error:", error);
    return { error: error.toString() };
  }
}
