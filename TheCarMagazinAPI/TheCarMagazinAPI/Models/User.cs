using System;

namespace TheCarMagazinAPI.Models
{
    public class User
    {
        public int Id { get; set; } // Azonosító
        public string Username { get; set; } // Felhasználónév
        public string Email { get; set; } // Email cím
        public string Password { get; set; } // Jelszó
        public DateTime CreatedAt { get; set; } // Létrehozás dátuma
    }

    public class UserRegistrationDto
    {
        public string Username { get; set; } // Felhasználónév
        public string Email { get; set; } // Email cím
        public string Password { get; set; } // Jelszó
    }

    public class UserLoginDto
    {
        public string Email { get; set; } // Email cím
        public string Password { get; set; } // Jelszó
    }
}
