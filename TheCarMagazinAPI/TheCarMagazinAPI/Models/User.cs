namespace TheCarMagazinAPI.Models
{
    public class UserDetailsDto
    {
        public long UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Bio { get; set; }
        public string? Status { get; set; }
        public string? ProfileImageUrl { get; set; }
        public string? Location { get; set; }
        public string? ContactEmail { get; set; }
        public Dictionary<string, string>? SocialMediaLinks { get; set; }
        public DateTime RegistrationDate { get; set; }
        public int PostCount { get; set; }
        public DateTime? LastActivity { get; set; }
        public string? UserRank { get; set; }
        public string? Signature { get; set; }
        public Dictionary<string, string>? PersonalLinks { get; set; }
        public List<string>? Hobbies { get; set; }
    }

    public class VerifyCodeDto
    {
        public long UserId { get; set; }
        public string Code { get; set; }
    }

    public class UserRegistrationDto
    {
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string HashingAlgorithm { get; set; } = "Argon2id";
    }

    public class UserLoginDto
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class User
    {
        public long Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string Language { get; set; } = "en";
        public string Role { get; set; } = "user";
        public string VerificationCode { get; set; } = string.Empty;
        public DateTime? VerificationCodeExpiry { get; set; }
        public bool IsVerified { get; set; }
        public string? Bio { get; set; }
        public string? Status { get; set; }
        public string? ProfileImageUrl { get; set; }
        public string? Location { get; set; }
        public string? ContactEmail { get; set; }
        public string? SocialMediaLinks { get; set; }
        public DateTime RegistrationDate { get; set; }
        public int PostCount { get; set; }
        public DateTime? LastActivity { get; set; }
        public string? UserRank { get; set; }
        public string? Signature { get; set; }
        public string? PersonalLinks { get; set; }
        public string? Hobbies { get; set; }
        public string HashingAlgorithm { get; set; } = "Bcrypt";
        public string? PasswordChangeCode { get; set; }
        public DateTime? PasswordChangeExpiry { get; set; }
        public string? PasswordChangeRequestId { get; set; }
        public string? PendingPassword { get; set; }
        public bool IsBanned { get; set; }
    }

    public class PasswordChangeRequestDto
    {
        public long UserId { get; set; }
        public string NewPassword { get; set; }
    }

    public class PasswordChangeVerifyDto
    {
        public long UserId { get; set; }
        public string RequestId { get; set; }
        public string Code { get; set; }
        public string NewPassword { get; set; } // Az új jelszót a kliens újra megadja
    }


}