using System;

namespace TheCarMagazinAPI.Models
{
    public class User
    {
        public int Id { get; set; }
        public string Username { get; set; }
        public string Email { get; set; }
        public string Password { get; set; }
        public string ProfileImageUrl { get; set; }
        public int CreatedTopicsCount { get; set; }
        public DateTime? LastLogin { get; set; }
        public string Bio { get; set; }
        public string Status { get; set; }
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

    public class UserDetailsDto
    {
        public int UserId { get; set; }
        public string ProfileImageUrl { get; set; }
        public int CreatedTopicsCount { get; set; }
        public DateTime? LastLogin { get; set; }
        public string Bio { get; set; }
        public string Status { get; set; }
    }


}
