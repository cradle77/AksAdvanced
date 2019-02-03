using Frontend.Data;
using KeyVaultWrapper;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

namespace Frontend
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddMvc()
                .SetCompatibilityVersion(CompatibilityVersion.Version_2_2);

            var keyVault = new KeyVaultConnection(Configuration.GetValue<string>("keyVaultUrl"));

            var redisConnectionString = keyVault.GetRedisConnectionString().Result;


            setupDataProtection(services, redisConnectionString);

            services.AddStackExchangeRedisCache(options =>
            {
                options.InstanceName = "SampleInstance";
                options.Configuration = redisConnectionString;
            });

            services.AddSingleton<IPeopleService>(x => new PeopleService(
                Configuration.GetSection("services").GetValue<string>("people"),
                x.GetService<IDistributedCache>()));

            services.AddHealthChecks()
                .AddRedis(redisConnectionString, name: "redis");
        }

        private void setupDataProtection(IServiceCollection services, string connectionString)
        {
            if (!Configuration.GetValue<bool>("isInCluster"))
                return;

            var redis = ConnectionMultiplexer.Connect(connectionString);

            services.AddDataProtection()
                .SetApplicationName("frontend-test")
                .PersistKeysToStackExchangeRedis(redis);
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
            }

            app.UseStaticFiles();

            app.UseHealthChecks("/healthz");

            app.UseMvc(routes =>
            {
                routes.MapRoute(
                    name: "default",
                    template: "{controller=Home}/{action=Index}/{id?}");
            });
        }
    }
}
