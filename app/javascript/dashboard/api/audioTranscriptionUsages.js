/* global axios */
import ApiClient from './ApiClient';

class AudioTranscriptionUsagesAPI extends ApiClient {
  constructor() {
    super('audio_transcription_usages', { accountScoped: true });
  }

  transcribeMessage({ conversationId, messageId }) {
    return axios.post(
      `${this.baseUrl()}/conversations/${conversationId}/messages/${messageId}/transcribe`
    );
  }
}

export default new AudioTranscriptionUsagesAPI();
