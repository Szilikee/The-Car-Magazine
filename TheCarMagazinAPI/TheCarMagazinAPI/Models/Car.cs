namespace TheCarMagazinAPI.Models
{
    public class CarListing
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int Year { get; set; }
        public int selling_price { get; set; } // Nullable
        public int km_driven { get; set; }    // Nullable
        public string Fuel { get; set; }
        public string seller_type { get; set; }
        public string Transmission { get; set; }
        public string Owner { get; set; }
    }



}
