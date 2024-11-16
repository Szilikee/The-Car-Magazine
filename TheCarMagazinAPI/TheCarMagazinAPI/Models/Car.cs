namespace TheCarMagazinAPI.Models
{
    public class CarListing
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string ImagePath { get; set; }
        public string Location { get; set; }
        public string Mileage { get; set; }
        public string Price { get; set; }
        public DateTime CreatedAt { get; set; }
    }

}
