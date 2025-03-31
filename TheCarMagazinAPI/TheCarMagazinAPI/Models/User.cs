using System;
using System.ComponentModel.DataAnnotations;

namespace TheCarMagazinAPI.Models
{
        public class User
        {
            public long Id { get; set; } // Changed to long
            public string Username { get; set; }
            public string Email { get; set; }
            public string Password { get; set; }
            public string? ProfileImageUrl { get; set; } // Nullable
            public int CreatedTopicsCount { get; set; }
            public DateTime? LastLogin { get; set; }
            public string? Bio { get; set; } // Nullable
            public string? Status { get; set; } // Nullable
            public string Language { get; set; } // Added
        }

        public class UserRegistrationDto
        {
            public string Username { get; set; }
            public string Email { get; set; }
            public string Password { get; set; }
        }

        public class UserLoginDto
        {
            public string Username { get; set; } // Changed to Username
            public string Password { get; set; }
        }

        public class UserDetailsDto
        {
            public long UserId { get; set; } // Changed to long
            public string? Bio { get; set; }
            public string? Status { get; set; }
        }
    }

