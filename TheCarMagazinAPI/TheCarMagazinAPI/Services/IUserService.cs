using TheCarMagazinAPI.DTOs;

namespace TheCarMagazinAPI.Services
{
    public interface IUserService
    {
        Task<UserDetailsDto> GetUserDetailsAsync(int userId);
        Task<bool> UpdateUserDetailsAsync(UserDetailsDto userDetailsDto);
    }

}
