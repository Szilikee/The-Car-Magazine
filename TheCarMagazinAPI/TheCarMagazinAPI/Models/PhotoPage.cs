namespace TheCarMagazinAPI.Models
{
    using System.Collections.Generic;
    using System.Text.Json.Serialization;

    public class PhotoPage
    {
        [JsonPropertyName("photos")]
        public List<Photo> Photos { get; set; } = new();
    }

    public class Photo
    {
        [JsonPropertyName("src")]
        public PhotoSrc Src { get; set; }
    }

    public class PhotoSrc
    {
        [JsonPropertyName("original")]
        public string Original { get; set; }
    }

}
