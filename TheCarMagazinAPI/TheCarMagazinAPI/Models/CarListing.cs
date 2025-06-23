namespace TheCarMagazinAPI.Models
{
    public class CarListing
    {
        public int Id { get; set; }
        public long UserId { get; set; } // New property
        public string Name { get; set; }
        public int Year { get; set; }
        public decimal SellingPrice { get; set; }
        public int KmDriven { get; set; }
        public string Fuel { get; set; }
        public string SellerType { get; set; }
        public string Transmission { get; set; }
        public string Contact { get; set; }
        public string? ImageUrl { get; set; }
        public string? ImageUrl2 { get; set; }
        public string? ImageUrl3 { get; set; }
        public string? ImageUrl4 { get; set; }
        public string? ImageUrl5 { get; set; }
        public string? Vin { get; set; }
        public int? EngineCapacity { get; set; }
        public int? Horsepower { get; set; }
        public string? BodyType { get; set; }
        public string? Color { get; set; }
        public int? NumberOfDoors { get; set; }
        public string? condition_ { get; set; }
        public string? SteeringSide { get; set; }
        public string? RegistrationStatus { get; set; }
        public string? Description { get; set; }
    }

    public class CarListingDto
    {
        public int Id { get; set; }
        public long UserId { get; set; } // New property
        public string Name { get; set; }
        public int Year { get; set; }
        public decimal SellingPrice { get; set; }
        public int KmDriven { get; set; }
        public string Fuel { get; set; }
        public string SellerType { get; set; }
        public string Transmission { get; set; }
        public string Contact { get; set; }
        public string? ImageUrl { get; set; }
        public string? ImageUrl2 { get; set; }
        public string? ImageUrl3 { get; set; }
        public string? ImageUrl4 { get; set; }
        public string? ImageUrl5 { get; set; }
        public string? Vin { get; set; }
        public int? EngineCapacity { get; set; }
        public int? Horsepower { get; set; }
        public string? BodyType { get; set; }
        public string? Color { get; set; }
        public int? NumberOfDoors { get; set; }
        public string? condition_ { get; set; }
        public string? SteeringSide { get; set; }
        public string? RegistrationStatus { get; set; }
        public string? Description { get; set; }
    }
}