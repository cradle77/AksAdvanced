using Microsoft.Azure.KeyVault;
using Microsoft.Azure.Services.AppAuthentication;
using Polly;
using Polly.Retry;
using System;
using System.Threading.Tasks;

namespace KeyVaultWrapper
{
    public class KeyVaultConnection
    {
        private string _keyVaultUrl;
        private RetryPolicy _retry;

        public KeyVaultConnection(string keyVaultUrl)
        {
            _keyVaultUrl = keyVaultUrl;
            _retry = Policy
                .Handle<Exception>()
                .WaitAndRetryAsync(3, x => TimeSpan.FromSeconds(5));
        }

        public async Task<string> GetSecretAsync(string name)
        {
            return await _retry.ExecuteAsync(async () => {
                Console.WriteLine("Accessing keyvault...");

                try
                {
                    AzureServiceTokenProvider provider = new AzureServiceTokenProvider();

                    var keyVaultClient = new KeyVaultClient(
                        new KeyVaultClient.AuthenticationCallback(provider.KeyVaultTokenCallback));

                    var secret = await keyVaultClient.GetSecretAsync(_keyVaultUrl, name)
                        .ConfigureAwait(false);

                    return secret.Value;
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Error: {0}", ex);
                    throw;
                }
            });
        }

        public async Task<string> GetCosmosDbConnectionString()
        {
            return await this.GetSecretAsync("cosmosdb");
        }

        public async Task<string> GetRedisConnectionString()
        {
            return await this.GetSecretAsync("redis");
        }
    }
}
