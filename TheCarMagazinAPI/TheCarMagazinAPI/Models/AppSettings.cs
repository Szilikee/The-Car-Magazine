namespace TheCarMagazinAPI.Models
{
    public class AppSettings
    {
        public string Secret { get; set; } = string.Empty;
        public string Issuer { get; set; } = string.Empty;
        public string Audience { get; set; } = string.Empty;
        public CloudinarySettings Cloudinary { get; set; } = new CloudinarySettings(); // Alapértelmezett inicializálás
    }

    public class CloudinarySettings
    {
        public string CloudName { get; set; } = string.Empty;
        public string ApiKey { get; set; } = string.Empty;
        public string ApiSecret { get; set; } = string.Empty;
        public string UploadPreset { get; set; } = string.Empty;
    }
}
