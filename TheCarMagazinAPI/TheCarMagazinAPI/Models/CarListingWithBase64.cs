namespace TheCarMagazinAPI.Models
{
    public class CarListingWithBase64
    {
        public string Title { get; set; }
        public string Location { get; set; }
        public string Mileage { get; set; }
        public string Price { get; set; }
        public string ImageBase64 { get; set; } // Base64 string a képről
    }

}
