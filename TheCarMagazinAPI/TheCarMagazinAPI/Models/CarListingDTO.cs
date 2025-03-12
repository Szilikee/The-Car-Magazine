namespace TheCarMagazinAPI.Models
{
    public class CarListingDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int Year { get; set; }
        public int SellingPrice { get; set; }
        public int KmDriven { get; set; }
        public string Fuel { get; set; }
        public string SellerType { get; set; }
        public string Transmission { get; set; }
        public string Owner { get; set; }
    }


}
