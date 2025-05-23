namespace TheCarMagazinAPI.Models
{
    public class CarListing
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int Year { get; set; }
        public decimal SellingPrice { get; set; }
        public int KmDriven { get; set; }
        public string Fuel { get; set; } = string.Empty;
        public string SellerType { get; set; } = string.Empty;
        public string Transmission { get; set; } = string.Empty;
        public string Owner { get; set; } = string.Empty;
        public string? ImageUrl { get; set; }
    }

    public class CarListingDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int Year { get; set; }
        public decimal SellingPrice { get; set; }
        public int KmDriven { get; set; }
        public string Fuel { get; set; } = string.Empty;
        public string SellerType { get; set; } = string.Empty;
        public string Transmission { get; set; } = string.Empty;
        public string Owner { get; set; } = string.Empty;
        public string? ImageUrl { get; set; }
    }
}