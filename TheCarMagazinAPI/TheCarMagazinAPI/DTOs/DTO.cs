using System.ComponentModel.DataAnnotations.Schema;

namespace TheCarMagazinAPI.DTOs
{
    public class UpdateTicketStatusDto
    {
        public string Status { get; set; }
    }

    public class DeleteTicketDto
    {
        public string UserEmail { get; set; }
        public string Subject { get; set; }
    }

    public class RespondTicketDto
    {
        public string UserEmail { get; set; }
        public string Subject { get; set; }
        public string ResponseText { get; set; }
    }

    // DTO for updating user details
    public class AdminUpdateUserDto
    {
        public long UserId { get; set; }
        public string? Password { get; set; }
        public string? Role { get; set; }
        public bool? IsVerified { get; set; }
        public bool? IsBanned { get; set; }
        public string? Username { get; set; }
        public string? Email { get; set; }
        public string? Bio { get; set; }
        public string? Status { get; set; }
        public string? ProfileImageUrl { get; set; }
        public string? Location { get; set; }
        public Dictionary<string, string>? SocialMediaLinks { get; set; }
        public string? UserRank { get; set; }
        public string? Signature { get; set; }
        public Dictionary<string, string>? PersonalLinks { get; set; }
        public List<string>? Hobbies { get; set; }
        public string? Language { get; set; }
        public string? HashingAlgorithm { get; set; }
    }

    // DTO for reporting content
    public class ReportContentDto
    {
        public string ContentType { get; set; } = string.Empty;
        public long ContentId { get; set; }
        public long UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string? Reason { get; set; }
    }

    // DTO for retrieving reported content
    public class ReportedContentDto
    {
        public long Id { get; set; }
        public string Type { get; set; } = string.Empty;
        public long ContentId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string ReportedBy { get; set; } = string.Empty;
        public long UserId { get; set; }
        public string? Reason { get; set; }
        public DateTime ReportedAt { get; set; }
        public long? SubtopicId { get; set; }
    }

    public class CarDetails
    {
        public string Genmodel_ID { get; set; }
        public string Maker { get; set; }
        public string Genmodel { get; set; }
        public string Trim { get; set; }
        public int Year { get; set; }
        public decimal Price { get; set; }
        public int Gas_emission { get; set; }
        public string Fuel_type { get; set; }
        public int Engine_size { get; set; }
    }

    public class CarImage
    {
        public string Image_ID { get; set; }
        public string Image_name { get; set; }
    }


    public class SubtopicDto
    {
        public string Title { get; set; }
        public string? Description { get; set; }
        public string? ImageUrl1 { get; set; }
        public string? ImageUrl2 { get; set; }
        public string? ImageUrl3 { get; set; }
    }

    public class PostDto
    {
        public string Content { get; set; }
        public long? ParentPostId { get; set; }
        public string? ImageUrl1 { get; set; }
        public string? ImageUrl2 { get; set; }
        public string? ImageUrl3 { get; set; }
    }

    public class VoteDto
    {
        public string VoteType { get; set; } // "upvote" or "downvote"
    }

    public class CreateArticleDto
    {
        public int UserId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public string Placement { get; set; } = "list";
        public string CreatedAt { get; set; } = string.Empty;
        public string LastUpdatedAt { get; set; } = string.Empty;
    }


    public class GoogleSignInRequestDto
    {
        public string IdToken { get; set; }
    }
    public class CreateSupportTicketDto
    {
        public string? UserId { get; set; }
        public string? Username { get; set; }
        public string? Email { get; set; }
        public string Subject { get; set; }
        public string Message { get; set; }
    }

    public class CreatePostDto
    {
        public long UserId { get; set; }
        public long SubtopicId { get; set; }
        public string Content { get; set; } = string.Empty;
        public long? ParentPostId { get; set; }
    }

    // DTO osztály az új végponthoz
    public class SupportMessageDto
    {
        public string? UserId { get; set; }
        public string? Username { get; set; }
        public string? Email { get; set; }
        public string Subject { get; set; }
        public string Message { get; set; }
    }


    public class SubmitTicketDto
    {
        public long UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Subject { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }

    public class EmailChangeRequestDto
    {
        public long UserId { get; set; }
        public string NewEmail { get; set; } = string.Empty;
    }

    public class EmailChangeVerifyDto
    {
        public long UserId { get; set; }
        public string RequestId { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public string NewEmail { get; set; } = string.Empty;
    }

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

    public class CarListingWithBase64
    {
        public string Title { get; set; }
        public string Location { get; set; }
        public string Mileage { get; set; }
        public string Price { get; set; }
        public string ImageBase64 { get; set; } // Base64 string a képről
    }

    public class ForumTopic
    {
        public int Id { get; set; }
        public string Topic { get; set; }
        public string Description { get; set; }
        [Column("created_at")] // Explicitly map to the database column
        public DateTime CreatedAt { get; set; }
    }

    public class Topic { public long Id { get; set; } public string TopicName { get; set; } /* ... */ }
    public class Subtopic
    {
        public long Id { get; set; }
        public long TopicId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public DateTime CreatedAt { get; set; }
        public long? UserId { get; set; }
        public string? Username { get; set; }
    }
    public class Post
    {
        public long Id { get; set; }
        public long UserId { get; set; }
        public long SubtopicId { get; set; }
        public string Content { get; set; }
        public long? ParentPostId { get; set; } // Nullable for top-level posts
        public DateTime CreatedAt { get; set; }
        public string Username { get; set; } // Optional: Include for display purposes
    }

    public class PredictionResult
    {
        public string Label { get; set; }
        public double Confidence { get; set; }
    }

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
